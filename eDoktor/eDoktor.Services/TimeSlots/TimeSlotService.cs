using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Auth;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.TimeSlots
{
    public class TimeSlotService : ITimeSlotService
    {
        private readonly eDoktorDbContext _db;
        private readonly ICurrentUserService _current;
        public TimeSlotService(eDoktorDbContext db, ICurrentUserService current) { _db = db; _current = current; }

        public async Task<List<TimeSlotResponse>> GetAsync(TimeSlotSearchObject s)
        {
            var q = _db.TimeSlots.AsQueryable();
            if (s.DoctorId.HasValue) q = q.Where(t => t.DoctorId == s.DoctorId.Value);
            if (s.From.HasValue) q = q.Where(t => t.StartUtc >= s.From.Value);
            if (s.To.HasValue) q = q.Where(t => t.StartUtc <= s.To.Value);
            if (s.OnlyAvailable == true) q = q.Where(t => !t.IsBooked && t.StartUtc > DateTime.UtcNow);
            q = q.OrderBy(t => t.StartUtc);
            // Bound the response so a wide date range can never return an unlimited number of slots.
            int take = Math.Clamp(s.PageSize ?? BaseSearchObject.MaxPageSize, 1, BaseSearchObject.MaxPageSize);
            int skip = Math.Max(s.Page ?? 0, 0) * take;
            q = q.Skip(skip).Take(take);
            var list = await q.ToListAsync();
            return list.Select(ToResponse).ToList();
        }

        public async Task<TimeSlotResponse> GetByIdAsync(int id)
        {
            var slot = await _db.TimeSlots.FirstOrDefaultAsync(t => t.Id == id)
                ?? throw new NotFoundException("Termin nije pronađen.");
            return ToResponse(slot);
        }

        // Moves a free slot to another time (same doctor), keeping it clear of the doctor's other slots.
        public async Task<TimeSlotResponse> UpdateAsync(int id, TimeSlotUpdateRequest req)
        {
            var slot = await _db.TimeSlots.FirstOrDefaultAsync(t => t.Id == id)
                ?? throw new NotFoundException("Termin nije pronađen.");
            await EnsureCanManageAsync(slot.DoctorId);

            var start = DateTime.SpecifyKind(req.StartUtc, DateTimeKind.Utc);
            var end = DateTime.SpecifyKind(req.EndUtc, DateTimeKind.Utc);
            if (slot.IsBooked)
                throw new UserException("Termin je rezervisan i ne može se mijenjati. Prvo otkažite ili pomjerite pregled.");
            if (end <= start)
                throw new UserException("Kraj termina mora biti nakon početka.");
            if (end - start > TimeSpan.FromHours(4))
                throw new UserException("Jedan termin ne može trajati duže od 4 sata.");
            if (start <= DateTime.UtcNow)
                throw new UserException("Termin se ne može pomjeriti u prošlost.");
            if (await _db.TimeSlots.AnyAsync(t => t.DoctorId == slot.DoctorId && t.Id != id && t.StartUtc < end && t.EndUtc > start))
                throw new UserException("Novo vrijeme se preklapa sa drugim terminom ovog ljekara.");

            slot.StartUtc = start;
            slot.EndUtc = end;
            try
            {
                await _db.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                throw new UserException("Termin je upravo zauzet, osvježite listu.");
            }
            return ToResponse(slot);
        }

        private static TimeSlotResponse ToResponse(TimeSlot t) => new()
        {
            Id = t.Id, DoctorId = t.DoctorId, StartUtc = t.StartUtc, EndUtc = t.EndUtc, IsBooked = t.IsBooked
        };

        public async Task<int> GenerateAsync(TimeSlotGenerateRequest req)
        {
            if (!await _db.Doctors.AnyAsync(d => d.Id == req.DoctorId && !d.IsDeleted))
                throw new NotFoundException("Ljekar nije pronađen.");
            await EnsureCanManageAsync(req.DoctorId);

            foreach (var w in req.Windows)
            {
                if (w.EndUtc <= w.StartUtc)
                    throw new UserException("Kraj radnog vremena mora biti nakon početka.");
                if (w.EndUtc - w.StartUtc > TimeSpan.FromHours(24))
                    throw new UserException("Radno vrijeme jednog dana ne može biti duže od 24 sata.");
                if ((w.EndUtc - w.StartUtc).TotalMinutes < req.SlotMinutes)
                    throw new UserException("Radno vrijeme je kraće od trajanja jednog termina.");
            }
            var from = req.Windows.Min(w => w.StartUtc);
            var to = req.Windows.Max(w => w.EndUtc);
            if (to <= DateTime.UtcNow)
                throw new UserException("Radno vrijeme se ne može unositi za prošle datume.");

            // Existing slots in the whole range, loaded once, so new slots never overlap them.
            var existing = await _db.TimeSlots
                .Where(t => t.DoctorId == req.DoctorId && t.StartUtc < to && t.EndUtc > from)
                .Select(t => new { t.StartUtc, t.EndUtc })
                .ToListAsync();

            var now = DateTime.UtcNow;
            var length = TimeSpan.FromMinutes(req.SlotMinutes);
            var slots = new List<TimeSlot>();
            foreach (var w in req.Windows.OrderBy(w => w.StartUtc))
            {
                for (var start = DateTime.SpecifyKind(w.StartUtc, DateTimeKind.Utc); start + length <= w.EndUtc; start += length)
                {
                    var end = start + length;
                    if (start <= now) continue;
                    if (existing.Any(e => e.StartUtc < end && e.EndUtc > start)) continue;
                    if (slots.Any(n => n.StartUtc < end && n.EndUtc > start)) continue;
                    slots.Add(new TimeSlot { DoctorId = req.DoctorId, StartUtc = start, EndUtc = end, IsBooked = false });
                }
            }

            _db.TimeSlots.AddRange(slots);
            await _db.SaveChangesAsync();
            return slots.Count;
        }

        public async Task DeleteAsync(int id)
        {
            var slot = await _db.TimeSlots.FirstOrDefaultAsync(t => t.Id == id)
                ?? throw new NotFoundException("Termin nije pronađen.");
            await EnsureCanManageAsync(slot.DoctorId);

            if (slot.IsBooked)
                throw new UserException("Termin je rezervisan i ne može se obrisati. Prvo otkažite ili pomjerite pregled.");
            if (await _db.Appointments.AnyAsync(a => a.TimeSlotId == id))
                throw new UserException("Termin je vezan za historiju pregleda i ne može se obrisati.");

            _db.TimeSlots.Remove(slot);
            await _db.SaveChangesAsync();
        }

        // Admins manage every doctor's schedule; a doctor only their own.
        private async Task EnsureCanManageAsync(int doctorId)
        {
            if (await _current.GetUserRoleAsync() == Roles.Admin) return;
            var uid = await _current.GetUserIdAsync();
            var ownDoctorId = await _db.Doctors.Where(d => d.UserId == uid).Select(d => (int?)d.Id).FirstOrDefaultAsync();
            if (ownDoctorId != doctorId)
                throw new ForbiddenException("Možete uređivati samo vlastito radno vrijeme.");
        }
    }
}

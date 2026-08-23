using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.TimeSlots
{
    public class TimeSlotService : ITimeSlotService
    {
        private readonly eDoktorDbContext _db;
        public TimeSlotService(eDoktorDbContext db) { _db = db; }

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
            return list.Select(t => new TimeSlotResponse
            {
                Id = t.Id, DoctorId = t.DoctorId, StartUtc = t.StartUtc, EndUtc = t.EndUtc, IsBooked = t.IsBooked
            }).ToList();
        }

        public async Task<int> GenerateAsync(TimeSlotGenerateRequest req)
        {
            var doctor = await _db.Doctors.FirstOrDefaultAsync(d => d.Id == req.DoctorId)
                ?? throw new UserException("Doctor not found");
            if (req.To < req.From) throw new UserException("Invalid date range");
            if (req.SlotMinutes <= 0 || req.SlotMinutes > 240) throw new UserException("Invalid slot length");

            var existing = await _db.TimeSlots
                .Where(t => t.DoctorId == req.DoctorId && t.StartUtc >= req.From && t.StartUtc <= req.To)
                .Select(t => t.StartUtc).ToListAsync();
            var existingSet = existing.ToHashSet();

            var slots = new List<TimeSlot>();
            for (var day = req.From.Date; day <= req.To.Date; day = day.AddDays(1))
            {
                for (var h = req.StartHour; h < req.EndHour; h++)
                {
                    for (var m = 0; m < 60; m += req.SlotMinutes)
                    {
                        var start = new DateTime(day.Year, day.Month, day.Day, h, m, 0, DateTimeKind.Utc);
                        if (existingSet.Contains(start)) continue;
                        slots.Add(new TimeSlot
                        {
                            DoctorId = req.DoctorId,
                            StartUtc = start,
                            EndUtc = start.AddMinutes(req.SlotMinutes),
                            IsBooked = false
                        });
                    }
                }
            }
            _db.TimeSlots.AddRange(slots);
            await _db.SaveChangesAsync();
            return slots.Count;
        }
    }
}

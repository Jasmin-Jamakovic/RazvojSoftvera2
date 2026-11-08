using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Auth;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.Notifications;
using eDoktor.Services.RabbitMQ;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.MedicalRecords
{
    public class MedicalRecordService : IMedicalRecordService
    {
        private readonly eDoktorDbContext _db;
        private readonly IRabbitMQService _rabbit;
        private readonly ICurrentUserService _current;
        private readonly INotificationService _notifications;
        public MedicalRecordService(eDoktorDbContext db, IRabbitMQService rabbit, ICurrentUserService current, INotificationService notifications)
        { _db = db; _rabbit = rabbit; _current = current; _notifications = notifications; }

        // A patient sees only their own record; a doctor only records of patients they have (had) an
        // appointment with; an admin sees all.
        private async Task EnsureCanAccessPatientAsync(int patientId)
        {
            var role = await _current.GetUserRoleAsync();
            var uid = await _current.GetUserIdAsync();
            var allowed = role switch
            {
                Roles.Admin => true,
                Roles.Patient => uid == patientId,
                Roles.Doctor => await _db.Appointments.AnyAsync(a => a.PatientId == patientId && a.Doctor.UserId == uid),
                _ => false
            };
            if (!allowed) throw new ForbiddenException("Nemate pristup kartonu ovog pacijenta.");
        }

        // ---------------------------------------------------------------- reading

        public async Task<MedicalRecordResponse?> GetForPatientAsync(int patientId)
        {
            await EnsureCanAccessPatientAsync(patientId);
            return await _db.MedicalRecords
                .Where(r => r.PatientId == patientId)
                .Select(r => new MedicalRecordResponse
                {
                    Id = r.Id,
                    PatientId = r.PatientId,
                    PatientName = r.Patient.FirstName + " " + r.Patient.LastName,
                    BloodType = r.Patient.BloodType,
                    Allergies = r.Patient.Allergies,
                    DateOfBirth = r.Patient.DateOfBirth,
                    EntryCount = r.Entries.Count,
                    PrescriptionCount = r.Entries.Count(e => e.Prescription != null),
                    LabResultCount = r.LabResults.Count
                })
                .FirstOrDefaultAsync();
        }

        public async Task<PagedResult<MedicalRecordEntryResponse>> GetEntriesAsync(int patientId, MedicalRecordSearchObject s)
        {
            await EnsureCanAccessPatientAsync(patientId);
            var q = EntriesQuery().Where(e => e.MedicalRecord.PatientId == patientId);
            if (!string.IsNullOrWhiteSpace(s.Search))
                q = q.Where(e => e.Diagnosis != null && e.Diagnosis.Contains(s.Search.Trim()));
            return await PageAsync(q.OrderByDescending(e => e.Appointment.TimeSlot.StartUtc), s, ToEntryResponse);
        }

        public async Task<PagedResult<PrescriptionResponse>> GetPrescriptionsAsync(int patientId, MedicalRecordSearchObject s)
        {
            await EnsureCanAccessPatientAsync(patientId);
            var q = PrescriptionsQuery().Where(p => p.MedicalRecordEntry.MedicalRecord.PatientId == patientId);
            if (!string.IsNullOrWhiteSpace(s.Search))
                q = q.Where(p => p.Items.Any(i => i.Medication.Contains(s.Search.Trim())));
            return await PageAsync(q.OrderByDescending(p => p.IssuedAt), s, ToPrescriptionResponse);
        }

        public async Task<PagedResult<LabResultResponse>> GetLabResultsAsync(int patientId, MedicalRecordSearchObject s)
        {
            await EnsureCanAccessPatientAsync(patientId);
            var q = LabResultsQuery().Where(l => l.MedicalRecord.PatientId == patientId);
            if (!string.IsNullOrWhiteSpace(s.Search))
                q = q.Where(l => l.Title.Contains(s.Search.Trim()));
            return await PageAsync(q.OrderByDescending(l => l.CreatedAt), s, ToLabResultResponse);
        }

        private static async Task<PagedResult<TOut>> PageAsync<TIn, TOut>(IQueryable<TIn> q, BaseSearchObject s, System.Func<TIn, TOut> map)
        {
            s.Normalize();
            int? total = s.IncludeTotalCount ? await q.CountAsync() : null;
            var items = await q.Skip(s.Page!.Value * s.PageSize!.Value).Take(s.PageSize!.Value).ToListAsync();
            return new PagedResult<TOut> { Items = items.Select(map).ToList(), TotalCount = total };
        }

        public async Task<MedicalRecordEntryResponse> GetEntryAsync(int id)
        {
            var e = await EntriesQuery().FirstOrDefaultAsync(x => x.Id == id) ?? throw new NotFoundException("Unos u kartonu nije pronađen.");
            await EnsureCanAccessPatientAsync(e.MedicalRecord.PatientId);
            return ToEntryResponse(e);
        }

        public async Task<PrescriptionResponse> GetPrescriptionAsync(int id)
        {
            var p = await PrescriptionsQuery().FirstOrDefaultAsync(x => x.Id == id) ?? throw new NotFoundException("Recept nije pronađen.");
            await EnsureCanAccessPatientAsync(p.MedicalRecordEntry.MedicalRecord.PatientId);
            return ToPrescriptionResponse(p);
        }

        public async Task<LabResultResponse> GetLabResultAsync(int id)
        {
            var l = await LabResultsQuery().FirstOrDefaultAsync(x => x.Id == id) ?? throw new NotFoundException("Nalaz nije pronađen.");
            await EnsureCanAccessPatientAsync(l.MedicalRecord.PatientId);
            return ToLabResultResponse(l);
        }

        // ---------------------------------------------------------------- visits (entries)

        public async Task<MedicalRecordEntryResponse> AddEntryAsync(MedicalRecordEntryUpsertRequest req, int doctorUserId)
        {
            var appt = await _db.Appointments.Include(a => a.Doctor).FirstOrDefaultAsync(a => a.Id == req.AppointmentId)
                ?? throw new NotFoundException("Termin nije pronađen.");
            if (appt.Doctor.UserId != doctorUserId) throw new ForbiddenException("Samo ljekar ovog pregleda može upisati nalaz u karton.");
            if (appt.StateMachine != nameof(ConfirmedAppointmentState) && appt.StateMachine != nameof(CompletedAppointmentState))
                throw new UserException("Nalaz se može upisati samo za potvrđen ili završen termin.");
            if (await _db.MedicalRecordEntries.AnyAsync(e => e.AppointmentId == appt.Id))
                throw new UserException("Za ovaj termin je već upisan nalaz. Uredite postojeći.");

            // A missing record is created together with the entry in a single SaveChanges.
            var record = await _db.MedicalRecords.FirstOrDefaultAsync(r => r.PatientId == appt.PatientId)
                ?? new MedicalRecord { PatientId = appt.PatientId };

            var entry = new MedicalRecordEntry
            {
                MedicalRecord = record,
                AppointmentId = appt.Id,
                Diagnosis = req.Diagnosis?.Trim(),
                Therapy = req.Therapy?.Trim(),
                Notes = req.Notes?.Trim()
            };
            _db.MedicalRecordEntries.Add(entry);
            await _db.SaveChangesAsync();
            return await GetEntryAsync(entry.Id);
        }

        public async Task<MedicalRecordEntryResponse> UpdateEntryAsync(int id, MedicalRecordEntryUpsertRequest req, int doctorUserId)
        {
            var e = await LoadOwnEntryAsync(id, doctorUserId, "Samo ljekar ovog pregleda može izmijeniti nalaz.");
            e.Diagnosis = req.Diagnosis?.Trim();
            e.Therapy = req.Therapy?.Trim();
            e.Notes = req.Notes?.Trim();
            await _db.SaveChangesAsync();
            return await GetEntryAsync(id);
        }

        public async Task DeleteEntryAsync(int id, int doctorUserId)
        {
            var e = await LoadOwnEntryAsync(id, doctorUserId, "Samo ljekar ovog pregleda može obrisati nalaz.");
            _db.MedicalRecordEntries.Remove(e); // its prescription goes with it (cascade)
            await _db.SaveChangesAsync();
        }

        private async Task<MedicalRecordEntry> LoadOwnEntryAsync(int id, int doctorUserId, string forbidden)
        {
            var e = await _db.MedicalRecordEntries.Include(x => x.Appointment).ThenInclude(a => a.Doctor)
                .FirstOrDefaultAsync(x => x.Id == id) ?? throw new NotFoundException("Unos u kartonu nije pronađen.");
            if (e.Appointment.Doctor.UserId != doctorUserId) throw new ForbiddenException(forbidden);
            return e;
        }

        // ---------------------------------------------------------------- prescriptions (master-details)

        public async Task<PrescriptionResponse> AddPrescriptionAsync(PrescriptionUpsertRequest req, int doctorUserId)
        {
            var entry = await _db.MedicalRecordEntries
                .Include(e => e.Appointment).ThenInclude(a => a.Doctor).ThenInclude(d => d.User)
                .Include(e => e.Appointment).ThenInclude(a => a.Patient)
                .FirstOrDefaultAsync(e => e.Id == req.MedicalRecordEntryId)
                ?? throw new NotFoundException("Unos u kartonu nije pronađen.");

            if (entry.Appointment.Doctor.UserId != doctorUserId) throw new ForbiddenException("Samo ljekar ovog pregleda može izdati recept.");

            if (await _db.Prescriptions.AnyAsync(p => p.MedicalRecordEntryId == entry.Id))
                throw new UserException("Za ovaj zapis u kartonu recept je već izdat.");

            var p = new Prescription { MedicalRecordEntryId = entry.Id, Items = ToItems(req) };
            var doctorName = $"{entry.Appointment.Doctor.User.FirstName} {entry.Appointment.Doctor.User.LastName}";

            await using (var tx = await _db.Database.BeginTransactionAsync())
            {
                _db.Prescriptions.Add(p);
                await _db.SaveChangesAsync();
                await _notifications.SendAsync(entry.Appointment.PatientId, "Novi recept",
                    $"Dr. {doctorName} vam je izdao/la recept ({p.Items.Count} lijek/a). Pogledajte ga u kartonu.", "prescription");
                await tx.CommitAsync();
            }

            await _rabbit.PublishAsync(QueueNames.PrescriptionIssued, new PrescriptionIssuedMessage
            {
                PrescriptionId = p.Id,
                AppointmentId = entry.AppointmentId,
                PatientId = entry.Appointment.PatientId,
                PatientEmail = entry.Appointment.Patient.Email,
                PatientName = $"{entry.Appointment.Patient.FirstName} {entry.Appointment.Patient.LastName}",
                DoctorName = doctorName
            });

            return await GetPrescriptionAsync(p.Id);
        }

        public async Task<PrescriptionResponse> UpdatePrescriptionAsync(int id, PrescriptionUpsertRequest req, int doctorUserId)
        {
            var p = await LoadOwnPrescriptionAsync(id, doctorUserId, "Samo ljekar koji je izdao recept ga može izmijeniti.");
            // The medication rows are replaced as a whole (master-details save).
            _db.PrescriptionItems.RemoveRange(p.Items);
            p.Items = ToItems(req);
            await _db.SaveChangesAsync();
            return await GetPrescriptionAsync(id);
        }

        public async Task DeletePrescriptionAsync(int id, int doctorUserId)
        {
            var p = await LoadOwnPrescriptionAsync(id, doctorUserId, "Samo ljekar koji je izdao recept ga može obrisati.");
            _db.Prescriptions.Remove(p);
            await _db.SaveChangesAsync();
        }

        private async Task<Prescription> LoadOwnPrescriptionAsync(int id, int doctorUserId, string forbidden)
        {
            var p = await _db.Prescriptions.Include(x => x.Items)
                .Include(x => x.MedicalRecordEntry).ThenInclude(e => e.Appointment).ThenInclude(a => a.Doctor)
                .FirstOrDefaultAsync(x => x.Id == id) ?? throw new NotFoundException("Recept nije pronađen.");
            if (p.MedicalRecordEntry.Appointment.Doctor.UserId != doctorUserId) throw new ForbiddenException(forbidden);
            return p;
        }

        private static System.Collections.Generic.List<PrescriptionItem> ToItems(PrescriptionUpsertRequest req)
        {
            if (req.Items.Count == 0) throw new UserException("Recept mora imati barem jedan lijek.");
            return req.Items.Select(i => new PrescriptionItem
            {
                Medication = i.Medication.Trim(), Dosage = i.Dosage?.Trim(), Frequency = i.Frequency?.Trim(), Duration = i.Duration?.Trim()
            }).ToList();
        }

        // ---------------------------------------------------------------- lab results

        public async Task<LabResultResponse> AddLabResultAsync(LabResultUpsertRequest req)
        {
            if (!await _db.Users.AnyAsync(u => u.Id == req.PatientId && u.Role.Name == Roles.Patient))
                throw new NotFoundException("Pacijent nije pronađen.");
            await EnsureCanAccessPatientAsync(req.PatientId);
            var record = await _db.MedicalRecords.FirstOrDefaultAsync(r => r.PatientId == req.PatientId)
                ?? new MedicalRecord { PatientId = req.PatientId };
            var l = new LabResult
            {
                MedicalRecord = record, Title = req.Title.Trim(), Notes = req.Notes?.Trim(),
                CreatedById = await _current.GetUserIdAsync()
            };

            await using (var tx = await _db.Database.BeginTransactionAsync())
            {
                _db.LabResults.Add(l);
                await _db.SaveChangesAsync();
                await _notifications.SendAsync(req.PatientId, "Novi nalaz",
                    $"Novi laboratorijski nalaz \"{l.Title}\" je dostupan u vašem kartonu.", "lab_result");
                await tx.CommitAsync();
            }
            return await GetLabResultAsync(l.Id);
        }

        public async Task<LabResultResponse> UpdateLabResultAsync(int id, LabResultUpsertRequest req)
        {
            var l = await LoadOwnLabResultAsync(id, "Nalaz može izmijeniti samo onaj ko ga je unio ili administrator.");
            l.Title = req.Title.Trim();
            l.Notes = req.Notes?.Trim();
            await _db.SaveChangesAsync();
            return await GetLabResultAsync(id);
        }

        public async Task DeleteLabResultAsync(int id)
        {
            var l = await LoadOwnLabResultAsync(id, "Nalaz može obrisati samo onaj ko ga je unio ili administrator.");
            _db.LabResults.Remove(l);
            await _db.SaveChangesAsync();
        }

        private async Task<LabResult> LoadOwnLabResultAsync(int id, string forbidden)
        {
            var l = await _db.LabResults.FirstOrDefaultAsync(x => x.Id == id) ?? throw new NotFoundException("Nalaz nije pronađen.");
            var role = await _current.GetUserRoleAsync();
            var uid = await _current.GetUserIdAsync();
            if (role != Roles.Admin && l.CreatedById != uid) throw new ForbiddenException(forbidden);
            return l;
        }

        // ---------------------------------------------------------------- queries + mapping

        private IQueryable<MedicalRecordEntry> EntriesQuery() => _db.MedicalRecordEntries
            .Include(e => e.MedicalRecord)
            .Include(e => e.Appointment).ThenInclude(a => a.Doctor).ThenInclude(d => d.User)
            .Include(e => e.Appointment).ThenInclude(a => a.Doctor).ThenInclude(d => d.DoctorSpecializations).ThenInclude(ds => ds.Specialization)
            .Include(e => e.Appointment).ThenInclude(a => a.TimeSlot)
            .Include(e => e.Prescription).ThenInclude(p => p!.Items)
            .AsSplitQuery();

        private IQueryable<Prescription> PrescriptionsQuery() => _db.Prescriptions
            .Include(p => p.Items)
            .Include(p => p.MedicalRecordEntry).ThenInclude(e => e.MedicalRecord)
            .Include(p => p.MedicalRecordEntry).ThenInclude(e => e.Appointment).ThenInclude(a => a.Doctor).ThenInclude(d => d.User)
            .AsSplitQuery();

        private IQueryable<LabResult> LabResultsQuery() => _db.LabResults
            .Include(l => l.MedicalRecord)
            .Include(l => l.CreatedBy);

        private static MedicalRecordEntryResponse ToEntryResponse(MedicalRecordEntry e) => new()
        {
            Id = e.Id,
            MedicalRecordId = e.MedicalRecordId,
            PatientId = e.MedicalRecord.PatientId,
            AppointmentId = e.AppointmentId,
            AppointmentDate = e.Appointment.TimeSlot.StartUtc,
            DoctorId = e.Appointment.DoctorId,
            DoctorName = $"{e.Appointment.Doctor.User.FirstName} {e.Appointment.Doctor.User.LastName}",
            Specialization = e.Appointment.Doctor.DoctorSpecializations.FirstOrDefault()?.Specialization?.Name,
            Diagnosis = e.Diagnosis,
            Therapy = e.Therapy,
            Notes = e.Notes,
            CreatedAt = e.CreatedAt,
            Prescription = e.Prescription == null ? null : ToPrescriptionResponse(e.Prescription, e)
        };

        private static PrescriptionResponse ToPrescriptionResponse(Prescription p) => ToPrescriptionResponse(p, p.MedicalRecordEntry);

        private static PrescriptionResponse ToPrescriptionResponse(Prescription p, MedicalRecordEntry e) => new()
        {
            Id = p.Id,
            MedicalRecordEntryId = p.MedicalRecordEntryId,
            AppointmentId = e.AppointmentId,
            IssuedAt = p.IssuedAt,
            DoctorName = e.Appointment?.Doctor?.User == null ? null : $"{e.Appointment.Doctor.User.FirstName} {e.Appointment.Doctor.User.LastName}",
            Diagnosis = e.Diagnosis,
            Items = p.Items.OrderBy(i => i.Id).Select(i => new PrescriptionItemResponse
            {
                Id = i.Id, Medication = i.Medication, Dosage = i.Dosage, Frequency = i.Frequency, Duration = i.Duration
            }).ToList()
        };

        private static LabResultResponse ToLabResultResponse(LabResult l) => new()
        {
            Id = l.Id,
            MedicalRecordId = l.MedicalRecordId,
            PatientId = l.MedicalRecord.PatientId,
            Title = l.Title,
            Notes = l.Notes,
            CreatedAt = l.CreatedAt,
            CreatedById = l.CreatedById,
            CreatedByName = l.CreatedBy == null ? null : $"{l.CreatedBy.FirstName} {l.CreatedBy.LastName}"
        };
    }
}

using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.RabbitMQ;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.MedicalRecords
{
    public class MedicalRecordService : IMedicalRecordService
    {
        private readonly eDoktorDbContext _db;
        private readonly IRabbitMQService _rabbit;
        public MedicalRecordService(eDoktorDbContext db, IRabbitMQService rabbit) { _db = db; _rabbit = rabbit; }

        public async Task<MedicalRecordResponse?> GetForPatientAsync(int patientId)
        {
            var record = await _db.MedicalRecords
                .Include(r => r.Patient)
                .Include(r => r.Entries).ThenInclude(e => e.Appointment).ThenInclude(a => a.Doctor).ThenInclude(d => d.User)
                .Include(r => r.Entries).ThenInclude(e => e.Appointment).ThenInclude(a => a.Doctor).ThenInclude(d => d.DoctorSpecializations).ThenInclude(ds => ds.Specialization)
                .Include(r => r.Entries).ThenInclude(e => e.Appointment).ThenInclude(a => a.TimeSlot)
                .Include(r => r.Entries).ThenInclude(e => e.Prescription).ThenInclude(p => p!.Items)
                .Include(r => r.LabResults)
                .FirstOrDefaultAsync(r => r.PatientId == patientId);
            if (record == null) return null;

            return new MedicalRecordResponse
            {
                Id = record.Id,
                PatientId = record.PatientId,
                PatientName = $"{record.Patient?.FirstName} {record.Patient?.LastName}",
                BloodType = record.Patient?.BloodType,
                Allergies = record.Patient?.Allergies,
                DateOfBirth = record.Patient?.DateOfBirth,
                Entries = record.Entries
                    .OrderByDescending(e => e.Appointment.TimeSlot.StartUtc)
                    .Select(e => new MedicalRecordEntryResponse
                    {
                        Id = e.Id,
                        MedicalRecordId = e.MedicalRecordId,
                        AppointmentId = e.AppointmentId,
                        AppointmentDate = e.Appointment.TimeSlot.StartUtc,
                        DoctorName = $"{e.Appointment.Doctor.User.FirstName} {e.Appointment.Doctor.User.LastName}",
                        Specialization = e.Appointment.Doctor.DoctorSpecializations.FirstOrDefault()?.Specialization?.Name,
                        Diagnosis = e.Diagnosis,
                        Therapy = e.Therapy,
                        Notes = e.Notes,
                        CreatedAt = e.CreatedAt,
                        Prescription = e.Prescription == null ? null : new PrescriptionResponse
                        {
                            Id = e.Prescription.Id,
                            MedicalRecordEntryId = e.Prescription.MedicalRecordEntryId,
                            AppointmentId = e.AppointmentId,
                            IssuedAt = e.Prescription.IssuedAt,
                            Items = e.Prescription.Items.Select(i => new PrescriptionItemResponse
                            {
                                Id = i.Id, Medication = i.Medication, Dosage = i.Dosage, Frequency = i.Frequency, Duration = i.Duration
                            }).ToList()
                        }
                    }).ToList(),
                LabResults = record.LabResults
                    .OrderByDescending(l => l.CreatedAt)
                    .Select(l => new LabResultResponse
                    {
                        Id = l.Id, MedicalRecordId = l.MedicalRecordId, Title = l.Title, Notes = l.Notes, FileUrl = l.FileUrl, CreatedAt = l.CreatedAt
                    }).ToList(),
                Prescriptions = record.Entries
                    .Where(e => e.Prescription != null)
                    .Select(e => new PrescriptionResponse
                    {
                        Id = e.Prescription!.Id,
                        MedicalRecordEntryId = e.Prescription.MedicalRecordEntryId,
                        AppointmentId = e.AppointmentId,
                        IssuedAt = e.Prescription.IssuedAt,
                        DoctorName = $"{e.Appointment.Doctor.User.FirstName} {e.Appointment.Doctor.User.LastName}",
                        Items = e.Prescription.Items.Select(i => new PrescriptionItemResponse
                        {
                            Id = i.Id, Medication = i.Medication, Dosage = i.Dosage, Frequency = i.Frequency, Duration = i.Duration
                        }).ToList()
                    }).ToList()
            };
        }

        public async Task<MedicalRecordEntryResponse> AddEntryAsync(MedicalRecordEntryUpsertRequest req, int doctorUserId)
        {
            var appt = await _db.Appointments.Include(a => a.Doctor).FirstOrDefaultAsync(a => a.Id == req.AppointmentId)
                ?? throw new UserException("Appointment not found");
            if (appt.Doctor.UserId != doctorUserId) throw new UserException("Only the treating doctor can add an entry");

            var record = await _db.MedicalRecords.FirstOrDefaultAsync(r => r.PatientId == appt.PatientId);
            if (record == null)
            {
                record = new MedicalRecord { PatientId = appt.PatientId };
                _db.MedicalRecords.Add(record);
                await _db.SaveChangesAsync();
            }

            var entry = new MedicalRecordEntry
            {
                MedicalRecordId = record.Id,
                AppointmentId = appt.Id,
                Diagnosis = req.Diagnosis,
                Therapy = req.Therapy,
                Notes = req.Notes
            };
            _db.MedicalRecordEntries.Add(entry);
            await _db.SaveChangesAsync();

            return new MedicalRecordEntryResponse
            {
                Id = entry.Id, MedicalRecordId = entry.MedicalRecordId, AppointmentId = entry.AppointmentId,
                Diagnosis = entry.Diagnosis, Therapy = entry.Therapy, Notes = entry.Notes, CreatedAt = entry.CreatedAt
            };
        }

        public async Task<PrescriptionResponse> AddPrescriptionAsync(PrescriptionUpsertRequest req, int doctorUserId)
        {
            var entry = await _db.MedicalRecordEntries
                .Include(e => e.Appointment).ThenInclude(a => a.Doctor).ThenInclude(d => d.User)
                .Include(e => e.Appointment).ThenInclude(a => a.Patient)
                .FirstOrDefaultAsync(e => e.Id == req.MedicalRecordEntryId)
                ?? throw new UserException("Record entry not found");

            if (entry.Appointment.Doctor.UserId != doctorUserId) throw new UserException("Only the treating doctor may issue this prescription");

            var existing = await _db.Prescriptions.FirstOrDefaultAsync(p => p.MedicalRecordEntryId == entry.Id);
            if (existing != null) throw new UserException("Prescription already issued for this record entry");

            var p = new Prescription
            {
                MedicalRecordEntryId = entry.Id,
                Items = req.Items.Select(i => new PrescriptionItem
                {
                    Medication = i.Medication, Dosage = i.Dosage, Frequency = i.Frequency, Duration = i.Duration
                }).ToList()
            };
            _db.Prescriptions.Add(p);
            await _db.SaveChangesAsync();

            await _rabbit.PublishAsync(QueueNames.PrescriptionIssued, new PrescriptionIssuedMessage
            {
                PrescriptionId = p.Id,
                AppointmentId = entry.AppointmentId,
                PatientId = entry.Appointment.PatientId,
                PatientEmail = entry.Appointment.Patient.Email,
                PatientName = $"{entry.Appointment.Patient.FirstName} {entry.Appointment.Patient.LastName}",
                DoctorName = $"{entry.Appointment.Doctor.User.FirstName} {entry.Appointment.Doctor.User.LastName}"
            });

            return new PrescriptionResponse
            {
                Id = p.Id,
                MedicalRecordEntryId = p.MedicalRecordEntryId,
                AppointmentId = entry.AppointmentId,
                IssuedAt = p.IssuedAt,
                Items = p.Items.Select(i => new PrescriptionItemResponse
                {
                    Id = i.Id, Medication = i.Medication, Dosage = i.Dosage, Frequency = i.Frequency, Duration = i.Duration
                }).ToList()
            };
        }

        public async Task<LabResultResponse> AddLabResultAsync(LabResultUpsertRequest req)
        {
            var record = await _db.MedicalRecords.FirstOrDefaultAsync(r => r.PatientId == req.PatientId);
            if (record == null)
            {
                record = new MedicalRecord { PatientId = req.PatientId };
                _db.MedicalRecords.Add(record);
                await _db.SaveChangesAsync();
            }
            var l = new LabResult { MedicalRecordId = record.Id, Title = req.Title, Notes = req.Notes, FileUrl = req.FileUrl };
            _db.LabResults.Add(l);
            await _db.SaveChangesAsync();

            return new LabResultResponse
            {
                Id = l.Id, MedicalRecordId = l.MedicalRecordId, Title = l.Title, Notes = l.Notes, FileUrl = l.FileUrl, CreatedAt = l.CreatedAt
            };
        }
    }
}

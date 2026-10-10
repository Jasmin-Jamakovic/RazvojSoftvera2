using System;
using System.Collections.Generic;
using System.Linq;
using eDoktor.Model;
using eDoktor.Services.Auth;
using eDoktor.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.Database
{
    public static class DataSeeder
    {
        private static byte[] Img(string b64) => Convert.FromBase64String(b64);

        // Small placeholder avatar PNGs so image-bearing entities actually have images in the seed
        // (spec §3.1: "Seed mora sadržavati i slike ako domena koristi slike").
        private static readonly byte[] Doc1Photo = Img("iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAIAAABt+uBvAAAAjklEQVR42u3QMQ0AAAgDsKlBI7pQiANOriZV0FQPhygQJEiQIEGCBAlCkCBBggQJEiQIQYIECRIkSJAgBAkSJEiQIEGCBCFIkCBBggQJEoQgQYIECRIkSBCCBAkSJEiQIEGCECRIkCBBggQJQpAgQYIECRIkCEGCBAkSJEiQIEEIEiRIkCBBggQhSJCgPwvJYkLCdcNzzwAAAABJRU5ErkJggg==");
        private static readonly byte[] Doc2Photo = Img("iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAIAAABt+uBvAAAAjElEQVR42u3QMQ0AAAgDsEmbenThgJOrSRU003KIAkGCBAkSJEiQIAQJEiRIkCBBghAkSJAgQYIECUKQIEGCBAkSJEgQggQJEiRIkCBBCBIkSJAgQYIEIUiQIEGCBAkSJAhBggQJEiRIkCAECRIkSJAgQYIQJEiQIEGCBAkShCBBggQJEiRIEIIECfqzXGPapBrSMlIAAAAASUVORK5CYII=");
        private static readonly byte[] Doc3Photo = Img("iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAIAAABt+uBvAAAAjklEQVR42u3QMQ0AAAgDsMlCC8LQiwNOriZV0NQ0hygQJEiQIEGCBAlCkCBBggQJEiQIQYIECRIkSJAgBAkSJEiQIEGCBCFIkCBBggQJEoQgQYIECRIkSBCCBAkSJEiQIEGCECRIkCBBggQJQpAgQYIECRIkCEGCBAkSJEiQIEEIEiRIkCBBggQhSJCgPwvVI6JolHd5/AAAAABJRU5ErkJggg==");
        private static readonly byte[] Doc4Photo = Img("iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAIAAABt+uBvAAAAjklEQVR42u3QMQ0AAAgDsElFFUoQiANOriZV0HQNhygQJEiQIEGCBAlCkCBBggQJEiQIQYIECRIkSJAgBAkSJEiQIEGCBCFIkCBBggQJEoQgQYIECRIkSBCCBAkSJEiQIEGCECRIkCBBggQJQpAgQYIECRIkCEGCBAkSJEiQIEEIEiRIkCBBggQhSJCgPwvzy+t2hfigfwAAAABJRU5ErkJggg==");
        private static readonly byte[] PatientPhoto = Img("iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAIAAABt+uBvAAAAjklEQVR42u3QMQ0AAAgDsOlEBCJQjgNOriZV0FQPhygQJEiQIEGCBAlCkCBBggQJEiQIQYIECRIkSJAgBAkSJEiQIEGCBCFIkCBBggQJEoQgQYIECRIkSBCCBAkSJEiQIEGCECRIkCBBggQJQpAgQYIECRIkCEGCBAkSJEiQIEEIEiRIkCBBggQhSJCgPwusP2qzFk0RFQAAAABJRU5ErkJggg==");

        // Runs after EnsureCreated. Idempotent: only inserts what is missing.
        // Uses real BCrypt hashes so the seeded "stringst" credentials actually work.
        public static void Seed(eDoktorDbContext db, IPasswordHasher hasher)
        {
            if (db.Users.Any()) return;

            var hash = hasher.Hash("stringst");
            var users = new List<User>
            {
                new() { Id = 1, FirstName = "Admin", LastName = "User", Username = "admin", Email = "admin@edoktor.local", PasswordHash = hash, RoleId = 1, CreatedAt = DateTime.UtcNow },
                new() { Id = 2, FirstName = "Test", LastName = "Patient", Username = "patient1", Email = "patient1@edoktor.local", PasswordHash = hash, RoleId = 2, CreatedAt = DateTime.UtcNow, DateOfBirth = new DateTime(1992, 5, 14), Gender = "F", BloodType = "A+", CityId = 1, Latitude = 43.8563, Longitude = 18.4131, Image = PatientPhoto },
                new() { Id = 3, FirstName = "Drugi", LastName = "Pacijent", Username = "patient2", Email = "patient2@edoktor.local", PasswordHash = hash, RoleId = 2, CreatedAt = DateTime.UtcNow, DateOfBirth = new DateTime(1988, 11, 2), Gender = "M", BloodType = "0+", CityId = 2, Latitude = 44.7722, Longitude = 17.1910 },
                new() { Id = 10, FirstName = "Adnan", LastName = "Mehić", Username = "doktor.mehic", Email = "adnan.mehic@edoktor.local", PasswordHash = hash, RoleId = 3, CreatedAt = DateTime.UtcNow },
                new() { Id = 11, FirstName = "Lejla", LastName = "Begić", Username = "doktor.begic", Email = "lejla.begic@edoktor.local", PasswordHash = hash, RoleId = 3, CreatedAt = DateTime.UtcNow },
                new() { Id = 12, FirstName = "Mirza", LastName = "Hodžić", Username = "doktor.hodzic", Email = "mirza.hodzic@edoktor.local", PasswordHash = hash, RoleId = 3, CreatedAt = DateTime.UtcNow },
                new() { Id = 13, FirstName = "Amra", LastName = "Selimović", Username = "doktor.selimovic", Email = "amra.selimovic@edoktor.local", PasswordHash = hash, RoleId = 3, CreatedAt = DateTime.UtcNow }
            };

            var doctors = new List<Doctor>
            {
                new() { Id = 1, UserId = 10, ClinicId = 1, YearsExperience = 12, ConsultationPrice = 40m, ProfilePhoto = Doc1Photo, Bio = "Specijalista opće prakse i porodične medicine. Iskustvo u preventivnim pregledima, hroničnim bolestima i pedijatrijskim konsultacijama." },
                new() { Id = 2, UserId = 11, ClinicId = 1, YearsExperience = 18, ConsultationPrice = 70m, ProfilePhoto = Doc2Photo, Bio = "Interventna kardiologija, ehokardiografija, prevencija srčanih bolesti i hipertenzije. Magistar nauka iz oblasti kardiologije." },
                new() { Id = 3, UserId = 12, ClinicId = 2, YearsExperience = 8, ConsultationPrice = 55m, ProfilePhoto = Doc3Photo, Bio = "Klinička dermatologija, estetska dermatologija, dermatoskopija madeža, tretman akni i ekcema kod djece i odraslih." },
                new() { Id = 4, UserId = 13, ClinicId = 3, YearsExperience = 15, ConsultationPrice = 65m, ProfilePhoto = Doc4Photo, Bio = "Neurolog sa iskustvom u dijagnostici i liječenju glavobolja, migrene, epilepsije i degenerativnih bolesti nervnog sistema." }
            };

            db.Database.OpenConnection();
            try
            {
                db.Database.ExecuteSqlRaw("SET IDENTITY_INSERT [Users] ON");
                db.Users.AddRange(users);
                db.SaveChanges();
                db.Database.ExecuteSqlRaw("SET IDENTITY_INSERT [Users] OFF");

                db.Database.ExecuteSqlRaw("SET IDENTITY_INSERT [Doctors] ON");
                db.Doctors.AddRange(doctors);
                db.SaveChanges();
                db.Database.ExecuteSqlRaw("SET IDENTITY_INSERT [Doctors] OFF");
            }
            finally
            {
                db.Database.CloseConnection();
            }

            db.DoctorSpecializations.AddRange(
                new DoctorSpecialization { DoctorId = 1, SpecializationId = 1 },
                new DoctorSpecialization { DoctorId = 2, SpecializationId = 2 },
                new DoctorSpecialization { DoctorId = 3, SpecializationId = 3 },
                new DoctorSpecialization { DoctorId = 4, SpecializationId = 4 }
            );
            db.SaveChanges();

            // ---- Transactional / activity mock data -------------------------------
            // Built as object graphs so EF assigns the FKs (TimeSlotId, AppointmentId, …)
            // automatically. All times are relative to "now" so the data stays fresh.
            var patient1 = users[1]; // Id 2
            var patient2 = users[2]; // Id 3
            var dGeneral = doctors[0];
            var dCardio = doctors[1];
            var dDerma = doctors[2];
            var dNeuro = doctors[3];

            var today = DateTime.UtcNow.Date;

            // Medical records (one per patient).
            var mr1 = new MedicalRecord { Patient = patient1, CreatedAt = today.AddMonths(-6) };
            var mr2 = new MedicalRecord { Patient = patient2, CreatedAt = today.AddMonths(-4) };

            // Helper to build a booked slot for an appointment.
            TimeSlot BookedSlot(Doctor doc, DateTime startUtc) =>
                new() { Doctor = doc, StartUtc = startUtc, EndUtc = startUtc.AddMinutes(30), IsBooked = true };

            // ---- Completed appointment #1: patient1 + cardiologist (25 days ago) ----
            var apt1 = new Appointment
            {
                Patient = patient1,
                Doctor = dCardio,
                TimeSlot = BookedSlot(dCardio, today.AddDays(-25).AddHours(9)),
                Type = AppointmentType.InPerson,
                StateMachine = "CompletedAppointmentState",
                Price = dCardio.ConsultationPrice,
                CreatedAt = today.AddDays(-30)
            };
            var entry1 = new MedicalRecordEntry
            {
                MedicalRecord = mr1,
                Appointment = apt1,
                Diagnosis = "Esencijalna (primarna) hipertenzija – I10",
                Therapy = "Redukcija unosa soli, redovna fizička aktivnost, kontrola krvnog pritiska dva puta dnevno.",
                Notes = "Pacijentica navodi povremene glavobolje. EKG uredan. Kontrola za 30 dana.",
                CreatedAt = today.AddDays(-25)
            };
            entry1.Prescription = new Prescription
            {
                IssuedAt = today.AddDays(-25),
                Items = new HashSet<PrescriptionItem>
                {
                    new() { Medication = "Amlodipin", Dosage = "5 mg", Frequency = "1x dnevno", Duration = "30 dana" },
                    new() { Medication = "Magnezij", Dosage = "375 mg", Frequency = "1x dnevno", Duration = "30 dana" }
                }
            };
            var review1 = new Review
            {
                Appointment = apt1,
                Doctor = dCardio,
                Patient = patient1,
                Rating = 5,
                Comment = "Izuzetno ljubazan i temeljit doktor. Sve mi je detaljno objasnila.",
                CreatedAt = today.AddDays(-24)
            };

            // ---- Completed appointment #2: patient1 + general practice (10 days ago) ----
            var apt2 = new Appointment
            {
                Patient = patient1,
                Doctor = dGeneral,
                TimeSlot = BookedSlot(dGeneral, today.AddDays(-10).AddHours(11)),
                Type = AppointmentType.Online,
                StateMachine = "CompletedAppointmentState",
                Price = dGeneral.ConsultationPrice,
                CreatedAt = today.AddDays(-12)
            };
            var entry2 = new MedicalRecordEntry
            {
                MedicalRecord = mr1,
                Appointment = apt2,
                Diagnosis = "Akutna infekcija gornjih disajnih puteva – J06.9",
                Therapy = "Mirovanje, povećan unos tečnosti, simptomatska terapija.",
                Notes = "Online konsultacija. Bez znakova bakterijske infekcije.",
                CreatedAt = today.AddDays(-10)
            };
            entry2.Prescription = new Prescription
            {
                IssuedAt = today.AddDays(-10),
                Items = new HashSet<PrescriptionItem>
                {
                    new() { Medication = "Paracetamol", Dosage = "500 mg", Frequency = "do 3x dnevno", Duration = "5 dana" }
                }
            };
            var review2 = new Review
            {
                Appointment = apt2,
                Doctor = dGeneral,
                Patient = patient1,
                Rating = 4,
                Comment = "Brza i korisna online konsultacija.",
                CreatedAt = today.AddDays(-9)
            };

            // ---- Completed appointment #3: patient2 + cardiologist (15 days ago) ----
            var apt3 = new Appointment
            {
                Patient = patient2,
                Doctor = dCardio,
                TimeSlot = BookedSlot(dCardio, today.AddDays(-15).AddHours(13)),
                Type = AppointmentType.InPerson,
                StateMachine = "CompletedAppointmentState",
                Price = dCardio.ConsultationPrice,
                CreatedAt = today.AddDays(-18)
            };
            var entry3 = new MedicalRecordEntry
            {
                MedicalRecord = mr2,
                Appointment = apt3,
                Diagnosis = "Hiperlipidemija – E78.5",
                Therapy = "Dijeta sa smanjenim unosom zasićenih masti, kontrola lipidnog statusa za 3 mjeseca.",
                Notes = "Preporučena umjerena fizička aktivnost 30 min dnevno.",
                CreatedAt = today.AddDays(-15)
            };
            var review3 = new Review
            {
                Appointment = apt3,
                Doctor = dCardio,
                Patient = patient2,
                Rating = 5,
                Comment = "Profesionalan pristup, preporučujem.",
                CreatedAt = today.AddDays(-14)
            };

            // ---- Confirmed upcoming appointment: patient1 + dermatologist (in 3 days) ----
            var apt4 = new Appointment
            {
                Patient = patient1,
                Doctor = dDerma,
                TimeSlot = BookedSlot(dDerma, today.AddDays(3).AddHours(10)),
                Type = AppointmentType.Online,
                StateMachine = "ConfirmedAppointmentState",
                Price = dDerma.ConsultationPrice,
                CreatedAt = today.AddDays(-1)
            };

            // ---- Pending appointment: patient2 + neurologist (in 5 days) ----
            var apt5 = new Appointment
            {
                Patient = patient2,
                Doctor = dNeuro,
                TimeSlot = BookedSlot(dNeuro, today.AddDays(5).AddHours(14)),
                Type = AppointmentType.InPerson,
                StateMachine = "PendingAppointmentState",
                Price = dNeuro.ConsultationPrice,
                CreatedAt = today
            };

            // ---- Cancelled appointment: patient2 + general practice (2 days ago) ----
            var apt6 = new Appointment
            {
                Patient = patient2,
                Doctor = dGeneral,
                TimeSlot = BookedSlot(dGeneral, today.AddDays(-2).AddHours(9)),
                Type = AppointmentType.InPerson,
                StateMachine = "CancelledAppointmentState",
                Price = dGeneral.ConsultationPrice,
                CreatedAt = today.AddDays(-4),
                CancelledAt = today.AddDays(-3),
                CancellationReason = "Pacijent spriječen, traži novi termin."
            };

            // Audit trail of the seeded appointments: paid ones were confirmed automatically by the payment,
            // completed ones were closed by their doctor, apt6 was cancelled by the patient.
            foreach (var a in new[] { apt1, apt2, apt3, apt4, apt6 }) a.ConfirmedAt = a.CreatedAt.AddMinutes(5);
            foreach (var a in new[] { apt1, apt2, apt3 })
            {
                a.CompletedAt = a.TimeSlot.EndUtc;
                a.CompletedBy = users.First(u => u.Id == a.Doctor.UserId);
            }
            apt6.CancelledBy = patient2;

            db.Appointments.AddRange(apt1, apt2, apt3, apt4, apt5, apt6);
            db.MedicalRecordEntries.AddRange(entry1, entry2, entry3);
            db.Reviews.AddRange(review1, review2, review3);

            // Lab results attached to the medical records.
            db.LabResults.AddRange(
                new LabResult { MedicalRecord = mr1, Title = "Kompletna krvna slika (KKS)", Notes = "Svi parametri unutar referentnih vrijednosti.", CreatedAt = today.AddDays(-25) },
                new LabResult { MedicalRecord = mr1, Title = "Lipidni status", Notes = "LDL blago povišen (3.8 mmol/L). Preporučena kontrola ishrane.", CreatedAt = today.AddDays(-10) },
                new LabResult { MedicalRecord = mr2, Title = "Lipidni status", Notes = "Ukupni holesterol 6.4 mmol/L. Hiperlipidemija.", CreatedAt = today.AddDays(-15) }
            );

            // Notifications per patient.
            db.Notifications.AddRange(
                new Notification { User = patient1, Title = "Termin potvrđen", Body = "Vaš termin sa dr. Mirza Hodžić je potvrđen.", Type = "appointment", IsRead = false, CreatedAt = today.AddDays(-1) },
                new Notification { User = patient1, Title = "Novi nalaz dostupan", Body = "Rezultati laboratorijskih pretraga su dostupni u vašem kartonu.", Type = "lab_result", IsRead = true, CreatedAt = today.AddDays(-10) },
                new Notification { User = patient2, Title = "Zahtjev za termin zaprimljen", Body = "Vaš zahtjev za termin sa dr. Amra Selimović čeka potvrdu.", Type = "appointment", IsRead = false, CreatedAt = today }
            );

            // Free (unbooked) availability for each doctor over the next 7 days, so the
            // booking flow has slots to choose from. Weekdays only, 09:00–15:00.
            var freeSlots = new List<TimeSlot>();
            foreach (var doc in doctors)
            {
                for (int day = 1; day <= 7; day++)
                {
                    var date = today.AddDays(day);
                    if (date.DayOfWeek == DayOfWeek.Saturday || date.DayOfWeek == DayOfWeek.Sunday) continue;
                    foreach (var hour in new[] { 9, 10, 11, 13, 14 })
                    {
                        var start = date.AddHours(hour);
                        freeSlots.Add(new TimeSlot { Doctor = doc, StartUtc = start, EndUtc = start.AddMinutes(30), IsBooked = false });
                    }
                }
            }
            db.TimeSlots.AddRange(freeSlots);

            db.SaveChanges();

            // PayPal transaction history for the paid appointments (needs the appointment ids generated above).
            // apt6 was cancelled more than 24h ahead, so its payment has already been refunded.
            var paid = new[] { apt1, apt2, apt3, apt4, apt6 };
            var payments = paid.Select(a => new PayPalPayment
            {
                AppointmentId = a.Id,
                OrderId = $"SEED-ORDER-{a.Id}",
                CaptureId = $"SEED-CAPTURE-{a.Id}",
                Amount = a.Price,
                Currency = "EUR",
                Status = a == apt6 ? PaymentStatus.Refunded : PaymentStatus.Captured,
                CreatedAt = a.CreatedAt,
                CapturedAt = a.CreatedAt.AddMinutes(5),
                RefundedAt = a == apt6 ? a.CancelledAt : null
            }).ToList();
            db.PayPalPayments.AddRange(payments);
            db.SaveChanges();

            for (int i = 0; i < paid.Length; i++)
                paid[i].PayPalPaymentId = payments[i].Id;
            db.SaveChanges();
        }
    }
}

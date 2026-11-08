using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Services.Auth;
using eDoktor.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.Database
{
    public static class DataSeeder
    {
        // Avatar PNGs embedded in this assembly (Database/SeedImages), so image-bearing entities have images
        // in the seed (spec §3.1: "Seed mora sadržavati i slike ako domena koristi slike").
        private static byte[] Img(string name)
        {
            using var stream = typeof(DataSeeder).Assembly.GetManifestResourceStream($"SeedImages/{name}.png")
                ?? throw new InvalidOperationException($"Seed image '{name}' is missing.");
            using var ms = new System.IO.MemoryStream();
            stream.CopyTo(ms);
            return ms.ToArray();
        }

        private record Visit(string Diagnosis, string Therapy, string Notes, string[]? Meds, string? Lab);

        // Fixed ids, so the README credentials and the role-specific data below line up.
        private const int AdminId = 1;
        private const int MobilePatientId = 2;
        private const int DoctorUserId = 10;

        // Runs after EnsureCreated. Only seeds an empty database.
        // Uses real BCrypt hashes so the seeded "test" credentials actually work.
        public static async Task SeedAsync(eDoktorDbContext db, IPasswordHasher hasher)
        {
            if (await db.Users.AnyAsync()) return;

            var hash = hasher.Hash("test");
            var now = DateTime.UtcNow;

            User Patient(int id, string first, string last, string username, int cityId, double lat, double lng,
                DateTime dob, string gender, string? blood, string? allergies, string? photo, string phone) => new()
            {
                Id = id, FirstName = first, LastName = last, Username = username, Email = $"{username}@edoktor.local",
                PasswordHash = hash, RoleId = 2, CreatedAt = now, DateOfBirth = dob, Gender = gender, BloodType = blood,
                Allergies = allergies, CityId = cityId, Latitude = lat, Longitude = lng, PhoneNumber = phone,
                Image = photo == null ? null : Img(photo)
            };

            User DoctorUser(int id, string first, string last, string username, string phone) => new()
            {
                Id = id, FirstName = first, LastName = last, Username = username, Email = $"{username}@edoktor.local",
                PasswordHash = hash, RoleId = 3, CreatedAt = now, PhoneNumber = phone
            };

            var users = new List<User>
            {
                new() { Id = AdminId, FirstName = "Admin", LastName = "eDoktor", Username = "desktop", Email = "desktop@edoktor.local", PasswordHash = hash, RoleId = 1, CreatedAt = now },

                // Patients (role "patient"). "mobile" is the login for the mobile app.
                Patient(MobilePatientId, "Ajla", "Hasić", "mobile", 1, 43.8563, 18.4131, new DateTime(1992, 5, 14), "F", "A+", "Penicilin", "patient1", "+38761111222"),
                Patient(3, "Kenan", "Delić", "patient2", 2, 44.7722, 17.1910, new DateTime(1988, 11, 2), "M", "0+", null, "patient2", "+38765222333"),
                Patient(4, "Selma", "Kovačević", "patient3", 3, 43.3438, 17.8078, new DateTime(1979, 3, 21), "F", "B+", "Polen, prašina", "patient3", "+38763333444"),
                Patient(5, "Haris", "Mujić", "patient4", 4, 44.5384, 18.6671, new DateTime(2001, 7, 9), "M", "AB-", null, "patient4", "+38762444555"),
                Patient(6, "Lamija", "Softić", "patient5", 5, 44.2034, 17.9077, new DateTime(1995, 1, 30), "F", "0-", "Laktoza", null, "+38761555666"),
                Patient(7, "Tarik", "Bešlić", "patient6", 6, 44.8169, 15.8708, new DateTime(1969, 12, 17), "M", "A-", null, null, "+38762666777"),
                Patient(8, "Emina", "Zukić", "patient7", 1, 43.8486, 18.3564, new DateTime(1985, 6, 3), "F", "A+", "Aspirin", null, "+38763777888"),
                Patient(9, "Adis", "Omerović", "patient8", 7, 44.8726, 18.8106, new DateTime(1973, 9, 25), "M", "B-", null, null, "+38761888999"),

                // Doctors (role "doctor"). "doctor" is the easy login for the doctor menu in the desktop app.
                DoctorUser(DoctorUserId, "Adnan", "Mehić", "doctor", "+38761100100"),
                DoctorUser(11, "Lejla", "Begić", "doktor.begic", "+38761100101"),
                DoctorUser(12, "Mirza", "Hodžić", "doktor.hodzic", "+38761100102"),
                DoctorUser(13, "Amra", "Selimović", "doktor.selimovic", "+38761100103"),
                DoctorUser(14, "Emir", "Kurtović", "doktor.kurtovic", "+38761100104"),
                DoctorUser(15, "Nermina", "Alić", "doktor.alic", "+38761100105"),
                DoctorUser(16, "Dino", "Ramić", "doktor.ramic", "+38761100106"),
                DoctorUser(17, "Sanela", "Čaušević", "doktor.causevic", "+38761100107")
            };

            // Doctor i (1-based) has specialization i, so every specialization is covered.
            var doctors = new List<Doctor>
            {
                new() { Id = 1, UserId = 10, ClinicId = 1, YearsExperience = 12, ConsultationPrice = 40m, ProfilePhoto = Img("doctor1"), Bio = "Specijalista opće prakse i porodične medicine. Iskustvo u preventivnim pregledima, hroničnim bolestima i pedijatrijskim konsultacijama." },
                new() { Id = 2, UserId = 11, ClinicId = 1, YearsExperience = 18, ConsultationPrice = 70m, ProfilePhoto = Img("doctor2"), Bio = "Interventna kardiologija, ehokardiografija, prevencija srčanih bolesti i hipertenzije. Magistar nauka iz oblasti kardiologije." },
                new() { Id = 3, UserId = 12, ClinicId = 2, YearsExperience = 8, ConsultationPrice = 55m, ProfilePhoto = Img("doctor3"), Bio = "Klinička dermatologija, estetska dermatologija, dermatoskopija madeža, tretman akni i ekcema kod djece i odraslih." },
                new() { Id = 4, UserId = 13, ClinicId = 3, YearsExperience = 15, ConsultationPrice = 65m, ProfilePhoto = Img("doctor4"), Bio = "Neurolog sa iskustvom u dijagnostici i liječenju glavobolja, migrene, epilepsije i degenerativnih bolesti nervnog sistema." },
                new() { Id = 5, UserId = 14, ClinicId = 4, YearsExperience = 10, ConsultationPrice = 45m, ProfilePhoto = Img("doctor5"), Bio = "Pedijatar: sistematski pregledi, vakcinacija, respiratorne infekcije i alergije kod djece." },
                new() { Id = 6, UserId = 15, ClinicId = 5, YearsExperience = 21, ConsultationPrice = 80m, ProfilePhoto = Img("doctor6"), Bio = "Ortopedija i traumatologija: sportske povrede, bolovi u leđima i zglobovima, rehabilitacija nakon operacija." },
                new() { Id = 7, UserId = 16, ClinicId = 2, YearsExperience = 6, ConsultationPrice = 50m, ProfilePhoto = Img("doctor7"), Bio = "Oftalmolog: pregled vida, propisivanje naočala, glaukom, katarakta i suho oko." },
                new() { Id = 8, UserId = 17, ClinicId = 3, YearsExperience = 14, ConsultationPrice = 60m, ProfilePhoto = Img("doctor8"), Bio = "Ginekologija i akušerstvo: redovni pregledi, ultrazvuk, praćenje trudnoće i hormonalni poremećaji." }
            };

            await db.Database.OpenConnectionAsync();
            try
            {
                await db.Database.ExecuteSqlRawAsync("SET IDENTITY_INSERT [Users] ON");
                db.Users.AddRange(users);
                await db.SaveChangesAsync();
                await db.Database.ExecuteSqlRawAsync("SET IDENTITY_INSERT [Users] OFF");

                await db.Database.ExecuteSqlRawAsync("SET IDENTITY_INSERT [Doctors] ON");
                db.Doctors.AddRange(doctors);
                await db.SaveChangesAsync();
                await db.Database.ExecuteSqlRawAsync("SET IDENTITY_INSERT [Doctors] OFF");
            }
            finally
            {
                await db.Database.CloseConnectionAsync();
            }

            db.DoctorSpecializations.AddRange(doctors.Select(d => new DoctorSpecialization { DoctorId = d.Id, SpecializationId = d.Id }));
            // Two doctors also cover a second field.
            db.DoctorSpecializations.Add(new DoctorSpecialization { DoctorId = 1, SpecializationId = 5 });
            db.DoctorSpecializations.Add(new DoctorSpecialization { DoctorId = 3, SpecializationId = 7 });
            await db.SaveChangesAsync();

            await SeedActivityAsync(db, users, doctors);
        }

        // ---- Transactional / activity data -------------------------------------------------------------
        // Built as object graphs so EF assigns the FKs automatically. All times are relative to "now" so the
        // data stays fresh; dates are the clinic's local days, slot times local working hours stored as UTC.
        private static async Task SeedActivityAsync(eDoktorDbContext db, List<User> users, List<Doctor> doctors)
        {
            var today = DisplayTime.ToLocal(DateTime.UtcNow).Date;
            var patients = users.Where(u => u.RoleId == 2).ToList();
            User UserOf(Doctor d) => users.First(u => u.Id == d.UserId);
            User PatientById(int id) => patients.First(p => p.Id == id);

            var records = patients.ToDictionary(p => p.Id, p => new MedicalRecord { Patient = p, CreatedAt = today.AddMonths(-8) });
            db.MedicalRecords.AddRange(records.Values);

            // Clinical content used for completed visits, by specialization (= doctor id).
            var visits = new Dictionary<int, Visit[]>
            {
                [1] = new Visit[]
                {
                    new Visit("Akutna infekcija gornjih disajnih puteva – J06.9", "Mirovanje, povećan unos tečnosti, simptomatska terapija.", "Bez znakova bakterijske infekcije.", new[] { "Paracetamol|500 mg|do 3x dnevno|5 dana" }, "Kompletna krvna slika (KKS)"),
                    new Visit("Deficit vitamina D – E55.9", "Suplementacija vitamina D, boravak na suncu.", "Kontrola nivoa vitamina D za 3 mjeseca.", new[] { "Vitamin D3|2000 IU|1x dnevno|90 dana" }, "Vitamin D (25-OH)")
                },
                [2] = new Visit[]
                {
                    new Visit("Esencijalna (primarna) hipertenzija – I10", "Redukcija unosa soli, fizička aktivnost, kontrola pritiska dva puta dnevno.", "EKG uredan. Kontrola za 30 dana.", new[] { "Amlodipin|5 mg|1x dnevno|30 dana", "Magnezij|375 mg|1x dnevno|30 dana" }, "Lipidni status"),
                    new Visit("Hiperlipidemija – E78.5", "Dijeta sa smanjenim unosom zasićenih masti.", "Preporučena umjerena fizička aktivnost 30 min dnevno.", new[] { "Atorvastatin|20 mg|1x dnevno uveče|90 dana" }, "Lipidni status – kontrola")
                },
                [3] = new Visit[]
                {
                    new Visit("Atopijski dermatitis – L20.9", "Emolijensi dva puta dnevno, izbjegavati iritanse.", "Lezije na pregibima laktova.", new[] { "Hidrokortizon krema 1%|tanki sloj|2x dnevno|7 dana" }, null),
                    new Visit("Acne vulgaris – L70.0", "Blago čišćenje, lokalna terapija.", "Kontrola za 6 sedmica.", new[] { "Adapalen gel|tanki sloj|1x dnevno uveče|42 dana" }, null)
                },
                [4] = new Visit[]
                {
                    new Visit("Migrena bez aure – G43.0", "Dnevnik glavobolja, redovan san, hidratacija.", "Neurološki status uredan.", new[] { "Sumatriptan|50 mg|po potrebi, max 2x dnevno|10 tableta" }, null),
                    new Visit("Tenzijska glavobolja – G44.2", "Fizioterapija vrata, tehnike relaksacije.", "Bez fokalnog deficita.", null, "Magnetna rezonanca glave")
                },
                [5] = new Visit[]
                {
                    new Visit("Akutni tonzilitis – J03.9", "Antibiotska terapija, topli napici.", "Bris grla pozitivan na streptokok.", new[] { "Amoksicilin|500 mg|3x dnevno|10 dana" }, "Bris grla"),
                    new Visit("Sistematski pregled – Z00.1", "Bez terapije.", "Rast i razvoj uredni.", null, null)
                },
                [6] = new Visit[]
                {
                    new Visit("Lumbalni bolni sindrom – M54.5", "Fizikalna terapija, izbjegavati podizanje tereta.", "Paravertebralna muskulatura spazmatična.", new[] { "Ibuprofen|400 mg|3x dnevno uz obrok|7 dana", "Tolperizon|150 mg|2x dnevno|10 dana" }, "RTG lumbosakralne kičme"),
                    new Visit("Distorzija skočnog zgloba – S93.4", "Mirovanje, led, elastični zavoj, elevacija.", "Bez znakova frakture.", new[] { "Diklofenak gel|tanki sloj|3x dnevno|10 dana" }, "RTG skočnog zgloba")
                },
                [7] = new Visit[]
                {
                    new Visit("Miopija – H52.1", "Korekcija naočalama.", "Vidna oštrina OU 0.6 bez korekcije.", null, null),
                    new Visit("Sindrom suhog oka – H04.1", "Umjetne suze, pauze pri radu za računarom.", "Schirmer test snižen.", new[] { "Umjetne suze|1 kap|4x dnevno|30 dana" }, null)
                },
                [8] = new Visit[]
                {
                    new Visit("Redovni ginekološki pregled – Z01.4", "Bez terapije.", "Nalaz uredan. Kontrola za godinu dana.", null, "PAPA test"),
                    new Visit("Sindrom policističnih jajnika – E28.2", "Regulacija tjelesne težine, kontrola hormona.", "Ultrazvuk potvrđuje policistične promjene.", new[] { "Metformin|500 mg|2x dnevno|90 dana" }, "Hormonski status")
                }
            };
            var reviewComments = new[]
            {
                "Izuzetno ljubazan i temeljit pregled. Sve mi je detaljno objašnjeno.",
                "Brza i korisna konsultacija, preporučujem.",
                "Profesionalan pristup i kratko čekanje.",
                "Doktor je bio strpljiv i odgovorio na sva pitanja.",
                "Dobar pregled, ali sam malo duže čekao/la.",
                null
            };

            var appointments = new List<Appointment>();
            var payments = new List<PayPalPayment>();
            var reviews = new List<Review>();
            var entries = new List<MedicalRecordEntry>();
            var labs = new List<LabResult>();

            Appointment Book(User patient, Doctor doctor, DateTime localStart, AppointmentType type, string state, DateTime createdAt)
            {
                var startUtc = DisplayTime.ToUtc(localStart);
                var a = new Appointment
                {
                    Patient = patient, Doctor = doctor, Type = type, StateMachine = state, Price = doctor.ConsultationPrice, CreatedAt = createdAt,
                    TimeSlot = new TimeSlot { Doctor = doctor, StartUtc = startUtc, EndUtc = startUtc.AddMinutes(30), IsBooked = state != "CancelledAppointmentState" }
                };
                appointments.Add(a);
                return a;
            }

            PayPalPayment Pay(Appointment a, string status)
            {
                var p = new PayPalPayment
                {
                    Appointment = a,
                    OrderId = $"SEED-ORDER-{appointments.IndexOf(a) + 1}",
                    CaptureId = $"{PayPal.PayPalService.SeedCapturePrefix}{appointments.IndexOf(a) + 1}",
                    Amount = a.Price,
                    Currency = "EUR",
                    Status = status,
                    CreatedAt = a.CreatedAt,
                    CapturedAt = a.CreatedAt.AddMinutes(5),
                    RefundedAt = status == PaymentStatus.Refunded ? a.CancelledAt : null
                };
                payments.Add(p);
                a.ConfirmedAt = p.CapturedAt; // paid appointments are confirmed automatically by the payment
                return p;
            }

            // ---- 24 completed visits in the past: every patient, every doctor, with record entries.
            for (int i = 0; i < 24; i++)
            {
                var patient = patients[i % patients.Count];
                var doctor = doctors[(i * 3 + i / 8) % doctors.Count];
                var start = today.AddDays(-(4 + i * 3)).AddHours(9 + i % 6);
                var a = Book(patient, doctor, start, i % 4 == 3 ? AppointmentType.Online : AppointmentType.InPerson,
                    "CompletedAppointmentState", start.AddDays(-3));
                Pay(a, PaymentStatus.Captured);
                a.CompletedAt = a.TimeSlot.EndUtc;
                a.CompletedBy = UserOf(doctor);

                var v = visits[doctor.Id][i % 2];
                var entry = new MedicalRecordEntry
                {
                    MedicalRecord = records[patient.Id], Appointment = a,
                    Diagnosis = v.Diagnosis, Therapy = v.Therapy, Notes = v.Notes, CreatedAt = a.TimeSlot.EndUtc
                };
                if (v.Meds != null)
                {
                    entry.Prescription = new Prescription
                    {
                        IssuedAt = a.TimeSlot.EndUtc,
                        Items = v.Meds.Select(m => m.Split('|')).Select(m => new PrescriptionItem
                        {
                            Medication = m[0], Dosage = m[1], Frequency = m[2], Duration = m[3]
                        }).ToList()
                    };
                }
                entries.Add(entry);
                if (v.Lab != null)
                {
                    labs.Add(new LabResult
                    {
                        MedicalRecord = records[patient.Id], CreatedBy = UserOf(doctor), Title = v.Lab,
                        Notes = i % 3 == 0 ? "Svi parametri unutar referentnih vrijednosti." : "Blago odstupanje od referentnih vrijednosti, kontrola preporučena.",
                        CreatedAt = a.TimeSlot.EndUtc.AddDays(1)
                    });
                }

                // Most completed visits were rated (one review per appointment).
                if (i % 6 != 5)
                {
                    reviews.Add(new Review
                    {
                        Appointment = a, Doctor = doctor, Patient = patient,
                        Rating = new[] { 5, 4, 5, 3, 5, 4, 5 }[i % 7],
                        Comment = reviewComments[i % reviewComments.Length],
                        CreatedAt = a.TimeSlot.EndUtc.AddDays(1)
                    });
                }
            }

            // ---- Upcoming confirmed (paid) appointments, 3–8 days ahead.
            var mobile = PatientById(MobilePatientId);
            var drMehic = doctors[0];
            for (int i = 0; i < 6; i++)
            {
                var patient = patients[(i + 1) % patients.Count];
                var doctor = doctors[(i + 2) % doctors.Count];
                var a = Book(patient, doctor, today.AddDays(3 + i).AddHours(8).AddMinutes(30), AppointmentType.InPerson,
                    "ConfirmedAppointmentState", today.AddDays(-1));
                Pay(a, PaymentStatus.Captured);
            }

            // ---- Pending appointments (booked, waiting for PayPal payment), 2–9 days ahead.
            //      The mobile patient has one with the "doctor" login so the pay → cancel → refund flow can be tried.
            var pendingForMobile = Book(mobile, drMehic, today.AddDays(2).AddHours(15), AppointmentType.Online, "PendingAppointmentState", today);
            for (int i = 0; i < 4; i++)
            {
                var patient = patients[(i + 3) % patients.Count];
                var doctor = doctors[(i + 5) % doctors.Count];
                Book(patient, doctor, today.AddDays(4 + i).AddHours(15).AddMinutes(30), AppointmentType.InPerson, "PendingAppointmentState", today);
            }

            // ---- For the "doctor" login: a paid online consultation that already took place but is not closed yet
            //      (the doctor can mark it completed and write the visit, prescription and lab result), with a chat.
            var toClose = Book(mobile, drMehic, today.AddDays(-1).AddHours(12), AppointmentType.Online, "ConfirmedAppointmentState", today.AddDays(-4));
            Pay(toClose, PaymentStatus.Captured);
            var room = new VideoCallSession { Appointment = toClose, RoomId = "edoktor-seed-consultation", StartedAt = toClose.TimeSlot.StartUtc, EndedAt = toClose.TimeSlot.EndUtc };
            var chatStart = toClose.TimeSlot.StartUtc;
            var drUser = UserOf(drMehic);
            var chat = new[]
            {
                (mobile, "Dobar dan doktore, imam temperaturu 38.2 već dva dana i bol u grlu."),
                (drUser, "Dobar dan. Imate li kašalj ili otežano gutanje?"),
                (mobile, "Gutanje me boli, kašalj je blag."),
                (drUser, "Možete li poslati fotografiju grla ili nalaz ako ga imate?"),
                (mobile, "Nemam nalaz, ali mogu doći na bris ako treba."),
                (drUser, "Uzmite paracetamol za temperaturu i dođite sutra na bris grla. Recept ću upisati u karton.")
            }.Select((m, i) => new ConsultationMessage { Appointment = toClose, Sender = m.Item1, Text = m.Item2, CreatedAt = chatStart.AddMinutes(i * 2) }).ToList();

            // ---- Cancelled appointments: by patients ≥24h ahead (refunded), by the practice, and unpaid ones.
            var cancelReasons = new[] { "Pacijent spriječen, traži novi termin.", "Ljekar odsutan zbog bolesti.", "Termin više nije potreban.", "Poslovne obaveze." };
            for (int i = 0; i < 6; i++)
            {
                var patient = patients[(i + 2) % patients.Count];
                var doctor = doctors[(i + 1) % doctors.Count];
                var a = Book(patient, doctor, today.AddDays(-(2 + i * 5)).AddHours(14).AddMinutes(30), AppointmentType.InPerson,
                    "CancelledAppointmentState", today.AddDays(-(8 + i * 5)));
                a.CancelledAt = a.CreatedAt.AddDays(2);
                a.CancellationReason = cancelReasons[i % cancelReasons.Length];
                var byStaff = i % cancelReasons.Length == 1;
                a.CancelledBy = byStaff ? UserOf(doctor) : patient;
                if (i % 3 != 2) Pay(a, PaymentStatus.Refunded); // every third one was cancelled before it was paid
            }

            db.Appointments.AddRange(appointments);
            db.PayPalPayments.AddRange(payments);
            db.MedicalRecordEntries.AddRange(entries);
            db.LabResults.AddRange(labs);
            db.Reviews.AddRange(reviews);
            db.VideoCallSessions.Add(room);
            db.ConsultationMessages.AddRange(chat);

            // ---- Search history: what patients looked for (feeds the recommender's patient profile).
            var searches = new (int PatientId, string? Query, int? SpecializationId, int DaysAgo)[]
            {
                (2, "kardiolog", 2, 40), (2, null, 2, 35), (2, "Begić", null, 30), (2, null, 3, 20), (2, "dermatolog Sarajevo", 3, 12), (2, null, 1, 3),
                (3, null, 4, 50), (3, "migrena", 4, 44), (3, null, 2, 15),
                (4, "pedijatar", 5, 60), (4, null, 5, 33), (4, null, 8, 9),
                (5, "ortoped", 6, 27), (5, "leđa", 6, 26), (5, null, 1, 4),
                (6, null, 7, 38), (6, "naočale", 7, 37), (6, null, 3, 6),
                (7, null, 2, 21), (7, "pritisak", 2, 20),
                (8, null, 8, 18), (8, "ginekolog", 8, 17),
                (9, null, 6, 11), (9, "koljeno", 6, 10), (9, null, 1, 2)
            };
            db.SearchHistories.AddRange(searches.Select(s => new SearchHistory
            {
                UserId = s.PatientId, Query = s.Query, SpecializationId = s.SpecializationId, CreatedAt = today.AddDays(-s.DaysAgo).AddHours(10)
            }));

            // ---- In-app notifications, read and unread, for patients and doctors.
            Notification N(int userId, string title, string body, string type, bool read, int daysAgo) =>
                new() { UserId = userId, Title = title, Body = body, Type = type, IsRead = read, CreatedAt = today.AddDays(-daysAgo).AddHours(9) };
            db.Notifications.AddRange(
                N(MobilePatientId, "Plaćanje uspješno", "Vaša uplata od 40.00 EUR je obrađena. Termin je potvrđen.", "payment", true, 4),
                N(MobilePatientId, "Termin potvrđen", "Vaš termin kod dr. Adnan Mehić je potvrđen.", "appointment", true, 4),
                N(MobilePatientId, "Novi recept", "Dr. Lejla Begić vam je izdala recept. Pogledajte ga u kartonu.", "prescription", false, 10),
                N(MobilePatientId, "Novi nalaz", "Novi laboratorijski nalaz \"Lipidni status\" je dostupan u vašem kartonu.", "lab_result", false, 9),
                N(MobilePatientId, "Termin zakazan", "Vaš termin kod dr. Adnan Mehić je zakazan i čeka plaćanje.", "appointment", false, 0),
                N(3, "Termin otkazan", "Vaš termin je otkazan. Novac je vraćen na vaš PayPal račun.", "appointment", true, 6),
                N(4, "Termin završen", "Vaš termin je označen kao završen. Možete ostaviti recenziju.", "appointment", false, 7),
                N(5, "Novi nalaz", "Novi laboratorijski nalaz \"RTG lumbosakralne kičme\" je dostupan u vašem kartonu.", "lab_result", false, 5),
                N(DoctorUserId, "Novi termin", "Pacijent Ajla Hasić je zakazao termin.", "appointment", false, 0),
                N(DoctorUserId, "Termin je plaćen", "Pacijent Ajla Hasić je platio termin (40.00 EUR). Termin je potvrđen.", "payment", true, 4),
                N(DoctorUserId, "Pacijent je otkazao termin", "Termin pacijenta Kenan Delić je otkazan. Razlog: Poslovne obaveze.", "appointment", true, 12),
                N(11, "Novi termin", "Pacijent Selma Kovačević je zakazala termin.", "appointment", false, 1),
                N(12, "Termin je plaćen", "Pacijent Haris Mujić je platio termin (55.00 EUR).", "payment", false, 2)
            );

            await db.SaveChangesAsync();

            // ---- Free (unbooked) availability for each doctor over the next 10 days, so the booking flow has
            //      slots to choose from. Weekdays only; never on top of a slot that is already booked.
            var busy = await db.TimeSlots.Select(t => new { t.DoctorId, t.StartUtc, t.EndUtc }).ToListAsync();
            var freeSlots = new List<TimeSlot>();
            foreach (var doc in doctors)
            {
                for (int day = 1; day <= 10; day++)
                {
                    var date = today.AddDays(day);
                    if (date.DayOfWeek == DayOfWeek.Saturday || date.DayOfWeek == DayOfWeek.Sunday) continue;
                    foreach (var hour in new[] { 9, 10, 11, 13, 14 })
                    {
                        var start = DisplayTime.ToUtc(date.AddHours(hour));
                        var end = start.AddMinutes(30);
                        if (busy.Any(b => b.DoctorId == doc.Id && b.StartUtc < end && start < b.EndUtc)) continue;
                        freeSlots.Add(new TimeSlot { DoctorId = doc.Id, StartUtc = start, EndUtc = end, IsBooked = false });
                    }
                }
            }
            db.TimeSlots.AddRange(freeSlots);
            await db.SaveChangesAsync();
        }
    }
}

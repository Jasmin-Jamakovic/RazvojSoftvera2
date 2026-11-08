using System;
using eDoktor.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.Database
{
    public class eDoktorDbContext : DbContext
    {
        public eDoktorDbContext(DbContextOptions<eDoktorDbContext> options) : base(options) { }

        public DbSet<User> Users { get; set; } = null!;
        public DbSet<Role> Roles { get; set; } = null!;
        public DbSet<Specialization> Specializations { get; set; } = null!;
        public DbSet<Country> Countries { get; set; } = null!;
        public DbSet<City> Cities { get; set; } = null!;
        public DbSet<Clinic> Clinics { get; set; } = null!;
        public DbSet<Doctor> Doctors { get; set; } = null!;
        public DbSet<DoctorSpecialization> DoctorSpecializations { get; set; } = null!;
        public DbSet<TimeSlot> TimeSlots { get; set; } = null!;
        public DbSet<Appointment> Appointments { get; set; } = null!;
        public DbSet<Review> Reviews { get; set; } = null!;
        public DbSet<MedicalRecord> MedicalRecords { get; set; } = null!;
        public DbSet<MedicalRecordEntry> MedicalRecordEntries { get; set; } = null!;
        public DbSet<Prescription> Prescriptions { get; set; } = null!;
        public DbSet<PrescriptionItem> PrescriptionItems { get; set; } = null!;
        public DbSet<LabResult> LabResults { get; set; } = null!;
        public DbSet<Notification> Notifications { get; set; } = null!;
        public DbSet<PayPalPayment> PayPalPayments { get; set; } = null!;
        public DbSet<VideoCallSession> VideoCallSessions { get; set; } = null!;
        public DbSet<PasswordResetCode> PasswordResetCodes { get; set; } = null!;
        public DbSet<ConsultationMessage> ConsultationMessages { get; set; } = null!;
        public DbSet<SearchHistory> SearchHistories { get; set; } = null!;

        // All times are stored in UTC, but SQL Server returns them without a kind, so they would be sent to the
        // apps without the "Z" suffix and shown as if they were local time. Mark them as UTC when reading.
        protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
        {
            configurationBuilder.Properties<DateTime>().HaveConversion<UtcDateTimeConverter>();
            configurationBuilder.Properties<DateTime?>().HaveConversion<UtcDateTimeConverter>();
        }

        private class UtcDateTimeConverter : Microsoft.EntityFrameworkCore.Storage.ValueConversion.ValueConverter<DateTime, DateTime>
        {
            public UtcDateTimeConverter() : base(
                v => v.Kind == DateTimeKind.Local ? v.ToUniversalTime() : v,
                v => DateTime.SpecifyKind(v, DateTimeKind.Utc))
            { }
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<User>().HasIndex(u => u.Username).IsUnique();
            modelBuilder.Entity<User>().HasIndex(u => u.Email).IsUnique();
            modelBuilder.Entity<Role>().HasIndex(r => r.Name).IsUnique();
            modelBuilder.Entity<Specialization>().HasIndex(s => s.Name).IsUnique();
            modelBuilder.Entity<City>().HasIndex(c => c.Name).IsUnique();
            modelBuilder.Entity<Country>().HasIndex(c => c.Name).IsUnique();

            modelBuilder.Entity<City>()
                .HasOne(c => c.Country).WithMany(c => c.Cities)
                .HasForeignKey(c => c.CountryId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<ConsultationMessage>()
                .HasOne(m => m.Appointment)
                .WithMany()
                .HasForeignKey(m => m.AppointmentId)
                .OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<ConsultationMessage>()
                .HasOne(m => m.Sender)
                .WithMany()
                .HasForeignKey(m => m.SenderId)
                .OnDelete(DeleteBehavior.Restrict);
            modelBuilder.Entity<ConsultationMessage>().HasIndex(m => new { m.AppointmentId, m.CreatedAt });

            modelBuilder.Entity<SearchHistory>()
                .HasOne(h => h.User)
                .WithMany()
                .HasForeignKey(h => h.UserId)
                .OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<SearchHistory>()
                .HasOne(h => h.Specialization)
                .WithMany()
                .HasForeignKey(h => h.SpecializationId)
                .OnDelete(DeleteBehavior.SetNull);
            modelBuilder.Entity<SearchHistory>().HasIndex(h => new { h.UserId, h.CreatedAt });

            modelBuilder.Entity<PasswordResetCode>()
                .HasOne(p => p.User)
                .WithMany()
                .HasForeignKey(p => p.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<User>()
                .HasOne(u => u.City).WithMany()
                .HasForeignKey(u => u.CityId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Clinic>()
                .HasOne(c => c.City).WithMany()
                .HasForeignKey(c => c.CityId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Doctor>()
                .HasOne(d => d.User)
                .WithOne(u => u.DoctorProfile!)
                .HasForeignKey<Doctor>(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Doctor>()
                .HasOne(d => d.Clinic)
                .WithMany(c => c.Doctors)
                .HasForeignKey(d => d.ClinicId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<DoctorSpecialization>()
                .HasKey(ds => new { ds.DoctorId, ds.SpecializationId });

            modelBuilder.Entity<DoctorSpecialization>()
                .HasOne(ds => ds.Doctor)
                .WithMany(d => d.DoctorSpecializations)
                .HasForeignKey(ds => ds.DoctorId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<DoctorSpecialization>()
                .HasOne(ds => ds.Specialization)
                .WithMany(s => s.DoctorSpecializations)
                .HasForeignKey(ds => ds.SpecializationId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<TimeSlot>()
                .HasOne(t => t.Doctor)
                .WithMany(d => d.TimeSlots)
                .HasForeignKey(t => t.DoctorId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<TimeSlot>()
                .HasIndex(t => new { t.DoctorId, t.StartUtc });

            modelBuilder.Entity<Appointment>()
                .HasOne(a => a.Patient)
                .WithMany(u => u.AppointmentsAsPatient)
                .HasForeignKey(a => a.PatientId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Appointment>()
                .HasOne(a => a.Doctor)
                .WithMany(d => d.Appointments)
                .HasForeignKey(a => a.DoctorId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Appointment>()
                .HasOne(a => a.TimeSlot)
                .WithMany()
                .HasForeignKey(a => a.TimeSlotId)
                .OnDelete(DeleteBehavior.Restrict);

            // Audit "who" columns: plain references, never cascading.
            modelBuilder.Entity<Appointment>().HasOne(a => a.ConfirmedBy).WithMany().HasForeignKey(a => a.ConfirmedById).OnDelete(DeleteBehavior.Restrict);
            modelBuilder.Entity<Appointment>().HasOne(a => a.CompletedBy).WithMany().HasForeignKey(a => a.CompletedById).OnDelete(DeleteBehavior.Restrict);
            modelBuilder.Entity<Appointment>().HasOne(a => a.CancelledBy).WithMany().HasForeignKey(a => a.CancelledById).OnDelete(DeleteBehavior.Restrict);
            modelBuilder.Entity<Appointment>().HasOne(a => a.RescheduledBy).WithMany().HasForeignKey(a => a.RescheduledById).OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<PayPalPayment>()
                .HasOne(p => p.Appointment)
                .WithMany(a => a.Payments)
                .HasForeignKey(p => p.AppointmentId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Review>()
                .HasOne(r => r.Doctor)
                .WithMany(d => d.Reviews)
                .HasForeignKey(r => r.DoctorId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Review>()
                .HasOne(r => r.Patient)
                .WithMany(u => u.ReviewsWritten)
                .HasForeignKey(r => r.PatientId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<Review>()
                .HasOne(r => r.Appointment)
                .WithOne(a => a.Review!)
                .HasForeignKey<Review>(r => r.AppointmentId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Review>()
                .HasIndex(r => r.AppointmentId).IsUnique();

            modelBuilder.Entity<MedicalRecord>()
                .HasOne(m => m.Patient)
                .WithOne(u => u.MedicalRecord!)
                .HasForeignKey<MedicalRecord>(m => m.PatientId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<MedicalRecordEntry>()
                .HasOne(e => e.MedicalRecord)
                .WithMany(m => m.Entries)
                .HasForeignKey(e => e.MedicalRecordId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<MedicalRecordEntry>()
                .HasOne(e => e.Appointment)
                .WithOne(a => a.MedicalRecordEntry!)
                .HasForeignKey<MedicalRecordEntry>(e => e.AppointmentId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<Prescription>()
                .HasOne(p => p.MedicalRecordEntry)
                .WithOne(e => e.Prescription!)
                .HasForeignKey<Prescription>(p => p.MedicalRecordEntryId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<PrescriptionItem>()
                .HasOne(pi => pi.Prescription)
                .WithMany(p => p.Items)
                .HasForeignKey(pi => pi.PrescriptionId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<LabResult>()
                .HasOne(l => l.MedicalRecord)
                .WithMany(m => m.LabResults)
                .HasForeignKey(l => l.MedicalRecordId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<LabResult>()
                .HasOne(l => l.CreatedBy).WithMany()
                .HasForeignKey(l => l.CreatedById)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<MedicalRecordEntry>().HasIndex(e => e.AppointmentId).IsUnique();

            modelBuilder.Entity<Notification>()
                .HasOne(n => n.User)
                .WithMany(u => u.Notifications)
                .HasForeignKey(n => n.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<VideoCallSession>()
                .HasOne(v => v.Appointment)
                .WithOne(a => a.VideoCallSession!)
                .HasForeignKey<VideoCallSession>(v => v.AppointmentId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<PayPalPayment>()
                .HasIndex(p => p.OrderId).IsUnique();

            // Seed data
            modelBuilder.Entity<Role>().HasData(
                new Role { Id = 1, Name = eDoktor.Model.Roles.Admin },
                new Role { Id = 2, Name = eDoktor.Model.Roles.Patient },
                new Role { Id = 3, Name = eDoktor.Model.Roles.Doctor }
            );

            modelBuilder.Entity<Specialization>().HasData(
                new Specialization { Id = 1, Name = "Opća praksa", Description = "Porodična medicina i opća praksa", IsDeleted = false },
                new Specialization { Id = 2, Name = "Kardiologija", Description = "Bolesti srca i krvnih sudova", IsDeleted = false },
                new Specialization { Id = 3, Name = "Dermatologija", Description = "Bolesti kože, kose i noktiju", IsDeleted = false },
                new Specialization { Id = 4, Name = "Neurologija", Description = "Bolesti nervnog sistema", IsDeleted = false },
                new Specialization { Id = 5, Name = "Pedijatrija", Description = "Zdravlje djece i adolescenata", IsDeleted = false },
                new Specialization { Id = 6, Name = "Ortopedija", Description = "Bolesti i povrede kostiju, zglobova i mišića", IsDeleted = false },
                new Specialization { Id = 7, Name = "Oftalmologija", Description = "Bolesti oka i vida", IsDeleted = false },
                new Specialization { Id = 8, Name = "Ginekologija", Description = "Reproduktivno zdravlje žena", IsDeleted = false }
            );

            modelBuilder.Entity<Country>().HasData(
                new Country { Id = 1, Name = "Bosna i Hercegovina", IsDeleted = false },
                new Country { Id = 2, Name = "Hrvatska", IsDeleted = false },
                new Country { Id = 3, Name = "Srbija", IsDeleted = false },
                new Country { Id = 4, Name = "Crna Gora", IsDeleted = false },
                new Country { Id = 5, Name = "Slovenija", IsDeleted = false }
            );

            modelBuilder.Entity<City>().HasData(
                new City { Id = 1, Name = "Sarajevo", CountryId = 1, IsDeleted = false },
                new City { Id = 2, Name = "Banja Luka", CountryId = 1, IsDeleted = false },
                new City { Id = 3, Name = "Mostar", CountryId = 1, IsDeleted = false },
                new City { Id = 4, Name = "Tuzla", CountryId = 1, IsDeleted = false },
                new City { Id = 5, Name = "Zenica", CountryId = 1, IsDeleted = false },
                new City { Id = 6, Name = "Bihać", CountryId = 1, IsDeleted = false },
                new City { Id = 7, Name = "Brčko", CountryId = 1, IsDeleted = false },
                new City { Id = 8, Name = "Trebinje", CountryId = 1, IsDeleted = false },
                new City { Id = 9, Name = "Zagreb", CountryId = 2, IsDeleted = false },
                new City { Id = 10, Name = "Split", CountryId = 2, IsDeleted = false },
                new City { Id = 11, Name = "Beograd", CountryId = 3, IsDeleted = false },
                new City { Id = 12, Name = "Novi Sad", CountryId = 3, IsDeleted = false },
                new City { Id = 13, Name = "Podgorica", CountryId = 4, IsDeleted = false },
                new City { Id = 14, Name = "Ljubljana", CountryId = 5, IsDeleted = false }
            );

            modelBuilder.Entity<Clinic>().HasData(
                new Clinic { Id = 1, Name = "Klinika Centar Sarajevo", Address = "Maršala Tita 12", CityId = 1, Latitude = 43.8563, Longitude = 18.4131, IsDeleted = false },
                new Clinic { Id = 2, Name = "Poliklinika Ilidža", Address = "Hrasnička cesta 3", CityId = 1, Latitude = 43.8278, Longitude = 18.3107, IsDeleted = false },
                new Clinic { Id = 3, Name = "Poliklinika Banja Luka", Address = "Vidovdanska 5", CityId = 2, Latitude = 44.7722, Longitude = 17.1910, IsDeleted = false },
                new Clinic { Id = 4, Name = "Dom zdravlja Mostar", Address = "Kralja Tvrtka 9", CityId = 3, Latitude = 43.3438, Longitude = 17.8078, IsDeleted = false },
                new Clinic { Id = 5, Name = "Poliklinika Tuzla", Address = "Turalibegova 20", CityId = 4, Latitude = 44.5384, Longitude = 18.6671, IsDeleted = false }
            );

            // Users, Doctors, DoctorSpecializations, MedicalRecords are seeded at runtime
            // (see DataSeeder) so passwords go through real BCrypt hashing.
        }
    }
}

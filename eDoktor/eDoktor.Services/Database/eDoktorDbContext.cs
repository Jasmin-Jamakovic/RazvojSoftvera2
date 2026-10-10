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

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<User>().HasIndex(u => u.Username).IsUnique();
            modelBuilder.Entity<User>().HasIndex(u => u.Email).IsUnique();
            modelBuilder.Entity<Role>().HasIndex(r => r.Name).IsUnique();
            modelBuilder.Entity<Specialization>().HasIndex(s => s.Name).IsUnique();
            modelBuilder.Entity<City>().HasIndex(c => c.Name).IsUnique();

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

            modelBuilder.Entity<Appointment>()
                .HasOne(a => a.Payment)
                .WithOne()
                .HasForeignKey<Appointment>(a => a.PayPalPaymentId)
                .OnDelete(DeleteBehavior.SetNull);

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
                new Specialization { Id = 4, Name = "Neurologija", Description = "Bolesti nervnog sistema", IsDeleted = false }
            );

            modelBuilder.Entity<City>().HasData(
                new City { Id = 1, Name = "Sarajevo", Country = "Bosna i Hercegovina", IsDeleted = false },
                new City { Id = 2, Name = "Banja Luka", Country = "Bosna i Hercegovina", IsDeleted = false },
                new City { Id = 3, Name = "Mostar", Country = "Bosna i Hercegovina", IsDeleted = false },
                new City { Id = 4, Name = "Tuzla", Country = "Bosna i Hercegovina", IsDeleted = false },
                new City { Id = 5, Name = "Zenica", Country = "Bosna i Hercegovina", IsDeleted = false },
                new City { Id = 6, Name = "Bihać", Country = "Bosna i Hercegovina", IsDeleted = false },
                new City { Id = 7, Name = "Brčko", Country = "Bosna i Hercegovina", IsDeleted = false },
                new City { Id = 8, Name = "Trebinje", Country = "Bosna i Hercegovina", IsDeleted = false }
            );

            modelBuilder.Entity<Clinic>().HasData(
                new Clinic { Id = 1, Name = "Klinika Centar Sarajevo", Address = "Maršala Tita 12", CityId = 1, Latitude = 43.8563, Longitude = 18.4131, IsDeleted = false },
                new Clinic { Id = 2, Name = "Poliklinika Ilidža", Address = "Hrasnička cesta 3", CityId = 1, Latitude = 43.8278, Longitude = 18.3107, IsDeleted = false },
                new Clinic { Id = 3, Name = "Poliklinika Banja Luka", Address = "Vidovdanska 5", CityId = 2, Latitude = 44.7722, Longitude = 17.1910, IsDeleted = false }
            );

            // Users, Doctors, DoctorSpecializations, MedicalRecords are seeded at runtime
            // (see DataSeeder) so passwords go through real BCrypt hashing.
        }
    }
}

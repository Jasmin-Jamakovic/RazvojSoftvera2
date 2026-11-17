using System;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.VideoCalls
{
    public class VideoCallOptions
    {
        // Jitsi server the rooms live on (from .env, VideoCall__BaseUrl).
        public string BaseUrl { get; set; } = string.Empty;
    }

    // Minimal Jitsi-style room creator. Returns a stable opaque room id that
    // both the patient and doctor clients use to join the same Jitsi room.
    public class VideoCallService : IVideoCallService
    {
        /// How early before the start the call can be opened (the mobile app uses the same 30 minutes).
        public static readonly TimeSpan JoinEarly = TimeSpan.FromMinutes(30);

        private readonly eDoktorDbContext _db;
        private readonly VideoCallOptions _opts;
        public VideoCallService(eDoktorDbContext db, VideoCallOptions opts) { _db = db; _opts = opts; }

        public async Task<(string RoomId, string JoinUrl)> GetOrCreateRoomAsync(int appointmentId, int userId)
        {
            var roomId = await GetOrCreateRoomIdAsync(appointmentId, userId);
            return (roomId, $"{_opts.BaseUrl.TrimEnd('/')}/{roomId}");
        }

        private async Task<string> GetOrCreateRoomIdAsync(int appointmentId, int userId)
        {
            var appt = await _db.Appointments.Include(a => a.Doctor).Include(a => a.VideoCallSession).Include(a => a.TimeSlot)
                .FirstOrDefaultAsync(a => a.Id == appointmentId)
                ?? throw new NotFoundException("Termin nije pronađen.");

            if (appt.PatientId != userId && appt.Doctor.UserId != userId)
                throw new ForbiddenException("Niste učesnik ove konsultacije.");
            if (appt.Type != AppointmentType.Online)
                throw new UserException("Termin nije online konsultacija.");
            // The same rule the mobile app shows: only a confirmed online appointment, from 30 minutes before
            // it starts until it ends. Checked here so a call can't be opened for a cancelled, unpaid or past one.
            if (appt.StateMachine != nameof(ConfirmedAppointmentState))
                throw new UserException("Videopoziv je moguć samo za potvrđen termin.");
            var now = DateTime.UtcNow;
            if (now < appt.TimeSlot.StartUtc - JoinEarly)
                throw new UserException($"Poziv možete otvoriti najranije {JoinEarly.TotalMinutes:0} minuta prije početka termina.");
            if (now > appt.TimeSlot.EndUtc)
                throw new UserException("Termin je završen, videopoziv više nije dostupan.");

            if (appt.VideoCallSession != null) return appt.VideoCallSession.RoomId;

            var room = $"edoktor-{appointmentId}-{Guid.NewGuid():N}".Substring(0, 36);
            _db.VideoCallSessions.Add(new VideoCallSession
            {
                AppointmentId = appointmentId,
                RoomId = room,
                StartedAt = DateTime.UtcNow
            });
            await _db.SaveChangesAsync();
            return room;
        }
    }
}

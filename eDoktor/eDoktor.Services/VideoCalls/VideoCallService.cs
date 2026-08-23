using System;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.VideoCalls
{
    // Minimal Jitsi-style room creator. Returns a stable opaque room id that
    // both the patient and doctor clients use to join the same Jitsi room.
    public class VideoCallService : IVideoCallService
    {
        private readonly eDoktorDbContext _db;
        public VideoCallService(eDoktorDbContext db) { _db = db; }

        public async Task<string> GetOrCreateRoomAsync(int appointmentId, int userId)
        {
            var appt = await _db.Appointments.Include(a => a.Doctor).Include(a => a.VideoCallSession)
                .FirstOrDefaultAsync(a => a.Id == appointmentId)
                ?? throw new UserException("Appointment not found");

            if (appt.PatientId != userId && appt.Doctor.UserId != userId)
                throw new UserException("Not a participant of this appointment");
            if (appt.Type != AppointmentType.Online)
                throw new UserException("Appointment is not an online consultation");

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

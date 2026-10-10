using System;
using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Auth;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.SignalR;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.VideoCalls
{
    // Chat during an online consultation. Only the appointment's patient and doctor can read or write;
    // new messages are pushed over SignalR to those two users only.
    public class ConsultationChatService : IConsultationChatService
    {
        public const string MessageEvent = "consultation:message";

        private readonly eDoktorDbContext _db;
        private readonly ICurrentUserService _current;
        private readonly IHubContext<NotificationHub> _hub;

        public ConsultationChatService(eDoktorDbContext db, ICurrentUserService current, IHubContext<NotificationHub> hub)
        {
            _db = db; _current = current; _hub = hub;
        }

        public async Task<PagedResult<ConsultationMessageResponse>> GetAsync(int appointmentId, BaseSearchObject s)
        {
            await LoadAsParticipantAsync(appointmentId);
            s.Normalize();
            var q = _db.ConsultationMessages.Where(m => m.AppointmentId == appointmentId);
            int? total = s.IncludeTotalCount ? await q.CountAsync() : null;
            // Newest first, so page 0 is the latest part of the conversation.
            var items = await q.OrderByDescending(m => m.CreatedAt).ThenByDescending(m => m.Id)
                .Skip(s.Page!.Value * s.PageSize!.Value).Take(s.PageSize!.Value)
                .Select(m => new ConsultationMessageResponse
                {
                    Id = m.Id,
                    AppointmentId = m.AppointmentId,
                    SenderId = m.SenderId,
                    SenderName = m.Sender.FirstName + " " + m.Sender.LastName,
                    Text = m.Text,
                    HasImage = m.Image != null,
                    CreatedAt = m.CreatedAt
                })
                .ToListAsync();
            return new PagedResult<ConsultationMessageResponse> { Items = items, TotalCount = total };
        }

        public async Task<ConsultationMessageResponse> SendAsync(int appointmentId, ConsultationMessageRequest req)
        {
            var (appt, userId) = await LoadAsParticipantAsync(appointmentId);
            if (appt.Type != AppointmentType.Online)
                throw new UserException("Chat je dostupan samo za online konsultacije.");
            if (appt.StateMachine != nameof(ConfirmedAppointmentState))
                throw new UserException("Poruke se mogu slati samo za potvrđenu konsultaciju.");

            var text = string.IsNullOrWhiteSpace(req.Text) ? null : req.Text.Trim();
            if (text == null && req.Image == null)
                throw new UserException("Unesite poruku ili priložite fotografiju.");
            if (req.Image != null && !ImageValidation.IsValidImage(req.Image))
                throw new UserException("Fotografija mora biti PNG, JPEG, GIF ili WEBP slika do 5 MB.");

            var sender = await _db.Users.FirstAsync(u => u.Id == userId);
            var msg = new ConsultationMessage { AppointmentId = appointmentId, SenderId = userId, Text = text, Image = req.Image };
            _db.ConsultationMessages.Add(msg);
            await _db.SaveChangesAsync();

            var dto = new ConsultationMessageResponse
            {
                Id = msg.Id,
                AppointmentId = appointmentId,
                SenderId = userId,
                SenderName = $"{sender.FirstName} {sender.LastName}",
                Text = msg.Text,
                HasImage = msg.Image != null,
                CreatedAt = msg.CreatedAt
            };
            await _hub.Clients.Groups($"user-{appt.PatientId}", $"user-{appt.Doctor.UserId}").SendAsync(MessageEvent, dto);
            return dto;
        }

        public async Task<(byte[] Bytes, string ContentType)> GetImageAsync(int appointmentId, int messageId)
        {
            await LoadAsParticipantAsync(appointmentId);
            var image = await _db.ConsultationMessages
                .Where(m => m.Id == messageId && m.AppointmentId == appointmentId)
                .Select(m => m.Image)
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Fotografija nije pronađena.");
            return (image, ImageValidation.DetectContentType(image) ?? "application/octet-stream");
        }

        private async Task<(Appointment Appt, int UserId)> LoadAsParticipantAsync(int appointmentId)
        {
            var userId = await _current.GetUserIdAsync() ?? throw new ForbiddenException("Niste prijavljeni.");
            var appt = await _db.Appointments.Include(a => a.Doctor).FirstOrDefaultAsync(a => a.Id == appointmentId)
                ?? throw new NotFoundException("Termin nije pronađen.");
            if (appt.PatientId != userId && appt.Doctor.UserId != userId)
                throw new ForbiddenException("Niste učesnik ove konsultacije.");
            return (appt, userId);
        }
    }
}

using System;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.RabbitMQ;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace eDoktor.Services.AppointmentStateMachine
{
    public class InitialAppointmentState : BaseAppointmentState
    {
        public InitialAppointmentState(IServiceProvider sp, IMapper mapper, eDoktorDbContext context)
            : base(sp, mapper, context) { }

        public override async Task<AppointmentResponse> CreateAsync(AppointmentCreateRequest req, int patientId)
        {
            var slot = await _context.TimeSlots.FirstOrDefaultAsync(t => t.Id == req.TimeSlotId)
                ?? throw new UserException("Time slot not found");
            if (slot.IsBooked) throw new UserException("Time slot is already booked");
            if (slot.DoctorId != req.DoctorId) throw new UserException("Slot does not belong to the chosen doctor");
            if (slot.StartUtc < DateTime.UtcNow) throw new UserException("Cannot book a slot in the past");

            var doctor = await _context.Doctors.FirstOrDefaultAsync(d => d.Id == req.DoctorId && !d.IsDeleted)
                ?? throw new UserException("Doctor not found");

            var appt = new Appointment
            {
                PatientId = patientId,
                DoctorId = req.DoctorId,
                TimeSlotId = req.TimeSlotId,
                Type = (AppointmentType)req.Type,
                Price = doctor.ConsultationPrice,
                CreatedAt = DateTime.UtcNow,
                StateMachine = nameof(PendingAppointmentState)
            };
            slot.IsBooked = true;
            _context.Appointments.Add(appt);
            await _context.SaveChangesAsync();

            // Patient + doctor info for messages
            var patient = await _context.Users.FirstOrDefaultAsync(u => u.Id == patientId);
            var doctorUser = await _context.Users.FirstOrDefaultAsync(u => u.Id == doctor.UserId);

            var rabbit = _serviceProvider.GetRequiredService<IRabbitMQService>();
            await rabbit.PublishAsync(QueueNames.AppointmentBooked, new AppointmentBookedMessage
            {
                AppointmentId = appt.Id,
                PatientId = appt.PatientId,
                DoctorId = appt.DoctorId,
                PatientEmail = patient?.Email ?? string.Empty,
                PatientName = $"{patient?.FirstName} {patient?.LastName}".Trim(),
                DoctorName = $"{doctorUser?.FirstName} {doctorUser?.LastName}".Trim(),
                StartUtc = slot.StartUtc,
                Type = appt.Type.ToString()
            });

            await NotifyAsync(appt.PatientId, "Termin zakazan",
                $"Vaš termin kod dr. {doctorUser?.FirstName} {doctorUser?.LastName} ({slot.StartUtc:dd.MM.yyyy. HH:mm}) je zakazan i čeka potvrdu.");

            return await ToResponse(appt.Id);
        }

        private async Task<AppointmentResponse> ToResponse(int id)
        {
            var a = await _context.Appointments
                .Include(x => x.Patient)
                .Include(x => x.Doctor).ThenInclude(d => d.User)
                .Include(x => x.TimeSlot)
                .Include(x => x.Payment)
                .Include(x => x.VideoCallSession)
                .FirstAsync(x => x.Id == id);

            return new AppointmentResponse
            {
                Id = a.Id,
                PatientId = a.PatientId,
                PatientName = $"{a.Patient.FirstName} {a.Patient.LastName}",
                DoctorId = a.DoctorId,
                DoctorName = $"{a.Doctor.User.FirstName} {a.Doctor.User.LastName}",
                TimeSlotId = a.TimeSlotId,
                StartUtc = a.TimeSlot.StartUtc,
                EndUtc = a.TimeSlot.EndUtc,
                Type = (int)a.Type,
                Status = a.StateMachine.Replace("AppointmentState", string.Empty),
                Price = a.Price,
                CreatedAt = a.CreatedAt,
                CancelledAt = a.CancelledAt,
                CancellationReason = a.CancellationReason,
                Payment = a.Payment == null ? null : _mapper.Map<PaymentResponse>(a.Payment),
                VideoRoomId = a.VideoCallSession?.RoomId
            };
        }
    }
}

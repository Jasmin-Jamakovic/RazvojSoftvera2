using System;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Messages;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.RabbitMQ;
using eDoktor.Services.Recommender;
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
                ?? throw new NotFoundException("Odabrani termin ne postoji.");
            if (slot.IsBooked) throw new UserException("Odabrani termin je već zauzet. Odaberite drugo vrijeme.");
            if (slot.DoctorId != req.DoctorId) throw new UserException("Odabrani termin ne pripada ovom ljekaru.");
            if (slot.StartUtc < DateTime.UtcNow) throw new UserException("Nije moguće zakazati termin u prošlosti.");
            if (!Enum.IsDefined(typeof(AppointmentType), req.Type)) throw new UserException("Nepoznata vrsta pregleda.");

            var doctor = await _context.Doctors.FirstOrDefaultAsync(d => d.Id == req.DoctorId && !d.IsDeleted)
                ?? throw new NotFoundException("Ljekar nije pronađen.");

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
            // Patient + doctor info for messages
            var patient = await _context.Users.FirstOrDefaultAsync(u => u.Id == patientId);
            var doctorUser = await _context.Users.FirstOrDefaultAsync(u => u.Id == doctor.UserId);

            await InTransactionAsync(async () =>
            {
                slot.IsBooked = true;
                _context.Appointments.Add(appt);
                await _context.SaveChangesAsync();
                await NotifyAsync(appt.PatientId, "Termin zakazan",
                    $"Vaš termin kod dr. {doctorUser?.FirstName} {doctorUser?.LastName} ({DisplayTime.Format(slot.StartUtc)}) je zakazan i čeka potvrdu.");
            });

            // Messages leave the system only after the booking is committed.
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

            // A new booking changes the patient's history, so their cached recommendations are stale.
            await _serviceProvider.GetRequiredService<IRecommenderService>().InvalidateAsync(appt.PatientId);

            return Map(await LoadAsync(appt.Id));
        }
    }
}

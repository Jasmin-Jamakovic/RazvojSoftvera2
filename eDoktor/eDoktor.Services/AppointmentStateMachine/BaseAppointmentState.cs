using System;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Services.Database;
using eDoktor.Services.Notifications;
using MapsterMapper;
using Microsoft.Extensions.DependencyInjection;

namespace eDoktor.Services.AppointmentStateMachine
{
    public class BaseAppointmentState
    {
        protected readonly IServiceProvider _serviceProvider;
        protected readonly IMapper _mapper;
        protected readonly eDoktorDbContext _context;

        public BaseAppointmentState(IServiceProvider sp, IMapper mapper, eDoktorDbContext context)
        {
            _serviceProvider = sp;
            _mapper = mapper;
            _context = context;
        }

        public virtual Task<AppointmentResponse> CreateAsync(AppointmentCreateRequest req, int patientId)
            => throw new UserException("Cannot create from current state");

        public virtual Task<AppointmentResponse> ConfirmAsync(int id)
            => throw new UserException("Cannot confirm from current state");

        public virtual Task<AppointmentResponse> CompleteAsync(int id)
            => throw new UserException("Cannot complete from current state");

        public virtual Task<AppointmentResponse> CancelAsync(int id, string? reason)
            => throw new UserException("Cannot cancel from current state");

        /// Creates an in-app notification (persisted + pushed over SignalR) for a user.
        protected async Task NotifyAsync(int userId, string title, string body, string type = "appointment")
        {
            var notifications = _serviceProvider.GetRequiredService<INotificationService>();
            await notifications.SendAsync(userId, title, body, type);
        }

        public BaseAppointmentState GetState(string name) => name switch
        {
            nameof(InitialAppointmentState) => _serviceProvider.GetRequiredService<InitialAppointmentState>(),
            nameof(PendingAppointmentState) => _serviceProvider.GetRequiredService<PendingAppointmentState>(),
            nameof(ConfirmedAppointmentState) => _serviceProvider.GetRequiredService<ConfirmedAppointmentState>(),
            nameof(CompletedAppointmentState) => _serviceProvider.GetRequiredService<CompletedAppointmentState>(),
            nameof(CancelledAppointmentState) => _serviceProvider.GetRequiredService<CancelledAppointmentState>(),
            _ => throw new UserException($"Unknown state {name}")
        };
    }
}

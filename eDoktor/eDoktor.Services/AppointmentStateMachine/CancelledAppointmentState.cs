using System;
using eDoktor.Services.Database;
using MapsterMapper;

namespace eDoktor.Services.AppointmentStateMachine
{
    public class CancelledAppointmentState : BaseAppointmentState
    {
        public CancelledAppointmentState(IServiceProvider sp, IMapper mapper, eDoktorDbContext context)
            : base(sp, mapper, context) { }

        // Terminal state.
    }
}

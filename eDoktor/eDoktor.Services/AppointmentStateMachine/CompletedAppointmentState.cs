using System;
using eDoktor.Services.Database;
using MapsterMapper;

namespace eDoktor.Services.AppointmentStateMachine
{
    public class CompletedAppointmentState : BaseAppointmentState
    {
        public CompletedAppointmentState(IServiceProvider sp, IMapper mapper, eDoktorDbContext context)
            : base(sp, mapper, context) { }

        // Terminal state - all base methods throw "cannot..." which is correct.
    }
}

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace eDoktor.Services.Database
{
    public static class DatabaseConfiguration
    {
        public static IServiceCollection AddEDoktorDbContext(this IServiceCollection services, string connectionString)
        {
            services.AddDbContext<eDoktorDbContext>(options =>
                options.UseSqlServer(connectionString));

            return services;
        }
    }
}

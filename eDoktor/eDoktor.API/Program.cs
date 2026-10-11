using System.Text;
using DotNetEnv;
using eDoktor.API.Filters;
using eDoktor.Services.Appointments;
using eDoktor.Services.AppointmentStateMachine;
using eDoktor.Services.Auth;
using eDoktor.Services.Cities;
using eDoktor.Services.Clinics;
using eDoktor.Services.Dashboard;
using eDoktor.Services.Database;
using eDoktor.Services.Doctors;
using eDoktor.Services.Geocoding;
using eDoktor.Services.Mapping;
using eDoktor.Services.MedicalRecords;
using eDoktor.Services.Notifications;
using eDoktor.Services.Payments;
using eDoktor.Services.PayPal;
using eDoktor.Services.RabbitMQ;
using eDoktor.Services.Recommender;
using eDoktor.Services.Redis;
using eDoktor.Services.Reminders;
using eDoktor.Services.Reviews;
using eDoktor.Services.SignalR;
using eDoktor.Services.Specializations;
using eDoktor.Services.TimeSlots;
using eDoktor.Services.Users;
using eDoktor.Services.VideoCalls;
using Mapster;
using MapsterMapper;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using StackExchange.Redis;

Env.Load(@"../.env");

var builder = WebApplication.CreateBuilder(args);

// Every setting comes from .env (via docker-compose); a missing value stops the start-up with a clear message
// instead of silently falling back to a value hidden in code.
static string Required(string name) => Environment.GetEnvironmentVariable(name)
    ?? throw new InvalidOperationException($"{name} is not configured (set it in .env).");

// DB — connection string comes from env (docker provides ConnectionStrings__DefaultConnection);
// for local runs it is composed from the .env values, so no secret lives in appsettings.json.
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
if (string.IsNullOrWhiteSpace(connectionString))
{
    connectionString = $"Server={Required("_source")},{Required("_sqlPort")};Database={Required("_catalog")};User=sa;Password={Required("_saPassword")};ConnectRetryCount=0;TrustServerCertificate=True";
}
builder.Services.AddEDoktorDbContext(connectionString);

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUserService, CurrentUserService>();

// JWT — key must be supplied via configuration; fail fast rather than boot with a known dev secret.
var jwtKey = Environment.GetEnvironmentVariable("Jwt__Key");
if (string.IsNullOrWhiteSpace(jwtKey) || Encoding.UTF8.GetByteCount(jwtKey) < 32)
    throw new InvalidOperationException("Jwt__Key must be configured and at least 32 bytes long (set it in .env).");
var jwtOpts = new JwtTokenOptions
{
    Issuer = Required("Jwt__Issuer"),
    Audience = Required("Jwt__Audience"),
    Key = jwtKey,
    ExpiryMinutes = int.Parse(Required("Jwt__ExpiryMinutes"))
};
builder.Services.AddSingleton(jwtOpts);
builder.Services.AddSingleton<IJwtTokenService, JwtTokenService>();
builder.Services.AddSingleton<IPasswordHasher, BcryptPasswordHasher>();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtOpts.Issuer,
            ValidAudience = jwtOpts.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOpts.Key))
        };
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var accessToken = ctx.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(accessToken) && ctx.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                    ctx.Token = accessToken;
                return Task.CompletedTask;
            },
            // Server-side revocation: reject tokens whose version no longer matches the user's
            // current TokenVersion (bumped on logout / password change).
            OnTokenValidated = async ctx =>
            {
                var idClaim = ctx.Principal?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
                var tvClaim = ctx.Principal?.FindFirst("tv")?.Value;
                if (!int.TryParse(idClaim, out var uid) || !int.TryParse(tvClaim, out var tv))
                {
                    ctx.Fail("Invalid token.");
                    return;
                }
                var db = ctx.HttpContext.RequestServices.GetRequiredService<eDoktorDbContext>();
                var current = await db.Users.Where(u => u.Id == uid && !u.IsDeleted)
                    .Select(u => (int?)u.TokenVersion).FirstOrDefaultAsync();
                if (current == null || current.Value != tv)
                    ctx.Fail("Token has been revoked.");
            }
        };
    });
builder.Services.AddAuthorization();

// Redis (optional): recommendations work without it, just uncached. An unreachable Redis is logged.
var redisConn = Environment.GetEnvironmentVariable("Redis__ConnectionString");
builder.Services.AddSingleton<IRedisCacheService>(sp =>
{
    if (string.IsNullOrWhiteSpace(redisConn)) return new NullRedisCacheService();
    try
    {
        return new RedisCacheService(ConnectionMultiplexer.Connect(redisConn));
    }
    catch (Exception ex)
    {
        sp.GetRequiredService<ILogger<Program>>().LogWarning(ex, "Redis at {Redis} is unreachable; recommendations will not be cached.", redisConn);
        return new NullRedisCacheService();
    }
});

// PayPal
var paypalOpts = new PayPalOptions
{
    // Client id/secret/webhook may be left empty in development: payments then report that PayPal is not configured.
    ClientId = Environment.GetEnvironmentVariable("PayPal__ClientId") ?? string.Empty,
    ClientSecret = Environment.GetEnvironmentVariable("PayPal__ClientSecret") ?? string.Empty,
    WebhookId = Environment.GetEnvironmentVariable("PayPal__WebhookId") ?? string.Empty,
    BaseUrl = Required("PayPal__BaseUrl"),
    Currency = Required("PayPal__Currency"),
    ReturnUrl = Required("PayPal__ReturnUrl"),
    CancelUrl = Required("PayPal__CancelUrl")
};
builder.Services.AddSingleton(paypalOpts);
builder.Services.AddHttpClient<IPayPalService, PayPalService>();
builder.Services.AddScoped<IPaymentService, PaymentService>();

// SignalR
builder.Services.AddSignalR();

// RabbitMQ - singleton; the connection is opened lazily with backoff on first publish,
// so the API can start before the broker is ready without blocking the startup thread.
builder.Services.AddSingleton<IRabbitMQService, RabbitMQService>();

// Domain services
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<ISpecializationService, SpecializationService>();
builder.Services.AddScoped<ICityService, CityService>();
builder.Services.AddScoped<IClinicService, ClinicService>();
builder.Services.AddScoped<IDoctorService, DoctorService>();
builder.Services.AddScoped<ITimeSlotService, TimeSlotService>();
builder.Services.AddScoped<IAppointmentService, AppointmentService>();
builder.Services.AddScoped<IReviewService, ReviewService>();
builder.Services.AddScoped<IMedicalRecordService, MedicalRecordService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<IRecommenderService, RecommenderService>();
builder.Services.AddScoped<IDashboardService, DashboardService>();
builder.Services.AddSingleton(new VideoCallOptions { BaseUrl = Required("VideoCall__BaseUrl") });
builder.Services.AddScoped<IVideoCallService, VideoCallService>();
builder.Services.AddScoped<IConsultationChatService, ConsultationChatService>();
builder.Services.AddSingleton(new GeocodingOptions { BaseUrl = Required("Geocoding__BaseUrl") });
builder.Services.AddHttpClient<IGeocodingService, GeocodingService>();

// Appointment reminders (24h / 1h before), run in the background inside the API.
builder.Services.AddHostedService<AppointmentReminderService>();

// Appointment state machine
builder.Services.AddScoped<InitialAppointmentState>();
builder.Services.AddScoped<PendingAppointmentState>();
builder.Services.AddScoped<ConfirmedAppointmentState>();
builder.Services.AddScoped<CompletedAppointmentState>();
builder.Services.AddScoped<CancelledAppointmentState>();

// Mapster
TypeAdapterConfig.GlobalSettings.Default.PreserveReference(true);
MappingConfig.Register();
builder.Services.AddSingleton(TypeAdapterConfig.GlobalSettings);
builder.Services.AddScoped<IMapper, ServiceMapper>();

// MVC + Swagger
builder.Services.AddControllers(o => o.Filters.Add<ExceptionFilter>());
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "eDoktor API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "JWT bearer token. Example: 'Bearer eyJhbGci...'"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        { new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } }, Array.Empty<string>() }
    });
});

// CORS — explicit allow-list (configurable via Cors__AllowedOrigins, comma-separated).
var corsOrigins = Required("Cors__AllowedOrigins")
    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.WithOrigins(corsOrigins).AllowAnyMethod().AllowAnyHeader()));

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var ctx = scope.ServiceProvider.GetRequiredService<eDoktorDbContext>();
    // EnsureCreated builds the schema and applies HasData seeds on first run.
    // No migrations are checked in because this project doesn't evolve the schema between releases.
    await ctx.Database.EnsureCreatedAsync();
    var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();
    await DataSeeder.SeedAsync(ctx, hasher);
}

// Swagger is API documentation (read-only); it is switched on/off in .env so it can be shown to reviewers
// while the API itself runs in Production mode (no developer exception pages).
if (bool.Parse(Required("Swagger__Enabled")))
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHub<NotificationHub>("/hubs/notifications");
app.Run();

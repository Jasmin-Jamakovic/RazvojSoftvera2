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
using eDoktor.Services.Mapping;
using eDoktor.Services.MedicalRecords;
using eDoktor.Services.Notifications;
using eDoktor.Services.Payments;
using eDoktor.Services.PayPal;
using eDoktor.Services.RabbitMQ;
using eDoktor.Services.Recommender;
using eDoktor.Services.Redis;
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

// DB — connection string comes from env (docker provides ConnectionStrings__DefaultConnection);
// for local runs it is composed from the .env values, so no secret lives in appsettings.json.
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
if (string.IsNullOrWhiteSpace(connectionString))
{
    var dbServer = Environment.GetEnvironmentVariable("_source") ?? "localhost";
    var dbCatalog = Environment.GetEnvironmentVariable("_catalog") ?? "eDoktor";
    var dbPassword = Environment.GetEnvironmentVariable("_saPassword")
        ?? throw new InvalidOperationException("No connection string and _saPassword is not set.");
    connectionString = $"Server={dbServer},1433;Database={dbCatalog};User=sa;Password={dbPassword};ConnectRetryCount=0;TrustServerCertificate=True";
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
    Issuer = Environment.GetEnvironmentVariable("Jwt__Issuer") ?? "eDoktor",
    Audience = Environment.GetEnvironmentVariable("Jwt__Audience") ?? "eDoktor",
    Key = jwtKey,
    ExpiryMinutes = int.TryParse(Environment.GetEnvironmentVariable("Jwt__ExpiryMinutes"), out var em) ? em : 1440
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

// Redis (optional)
var redisConn = Environment.GetEnvironmentVariable("Redis__ConnectionString");
if (!string.IsNullOrWhiteSpace(redisConn))
{
    try
    {
        var mux = ConnectionMultiplexer.Connect(redisConn);
        builder.Services.AddSingleton<IConnectionMultiplexer>(mux);
        builder.Services.AddSingleton<IRedisCacheService, RedisCacheService>();
    }
    catch
    {
        builder.Services.AddSingleton<IRedisCacheService, NullRedisCacheService>();
    }
}
else
{
    builder.Services.AddSingleton<IRedisCacheService, NullRedisCacheService>();
}

// PayPal
var paypalOpts = new PayPalOptions
{
    ClientId = Environment.GetEnvironmentVariable("PayPal__ClientId") ?? string.Empty,
    ClientSecret = Environment.GetEnvironmentVariable("PayPal__ClientSecret") ?? string.Empty,
    BaseUrl = Environment.GetEnvironmentVariable("PayPal__BaseUrl") ?? "https://api-m.sandbox.paypal.com",
    WebhookId = Environment.GetEnvironmentVariable("PayPal__WebhookId") ?? string.Empty,
    ReturnUrl = Environment.GetEnvironmentVariable("PayPal__ReturnUrl") ?? string.Empty,
    CancelUrl = Environment.GetEnvironmentVariable("PayPal__CancelUrl") ?? string.Empty
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
builder.Services.AddScoped<IVideoCallService, VideoCallService>();
builder.Services.AddScoped<IConsultationChatService, ConsultationChatService>();

// Appointment state machine
builder.Services.AddScoped<BaseAppointmentState>();
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
var corsOrigins = (Environment.GetEnvironmentVariable("Cors__AllowedOrigins")
        ?? "http://localhost:5190,http://127.0.0.1:5190,http://localhost:3000")
    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.WithOrigins(corsOrigins).AllowAnyMethod().AllowAnyHeader()));

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var ctx = scope.ServiceProvider.GetRequiredService<eDoktorDbContext>();
    // EnsureCreated builds the schema and applies HasData seeds on first run.
    // No migrations are checked in because this project doesn't evolve the schema between releases.
    ctx.Database.EnsureCreated();
    var hasher = scope.ServiceProvider.GetRequiredService<IPasswordHasher>();
    DataSeeder.Seed(ctx, hasher);
}

if (app.Environment.IsDevelopment())
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

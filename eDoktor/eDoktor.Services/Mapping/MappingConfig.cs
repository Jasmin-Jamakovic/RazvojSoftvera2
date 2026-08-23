using eDoktor.Model.Responses;
using eDoktor.Services.Database.Entities;
using Mapster;

namespace eDoktor.Services.Mapping
{
    public static class MappingConfig
    {
        public static void Register()
        {
            TypeAdapterConfig<PayPalPayment, PaymentResponse>.NewConfig();
            TypeAdapterConfig<Specialization, SpecializationResponse>.NewConfig();
            TypeAdapterConfig<City, CityResponse>.NewConfig();
            TypeAdapterConfig<Clinic, ClinicResponse>.NewConfig()
                .Map(dest => dest.CityName, src => src.City != null ? src.City.Name : null);
            TypeAdapterConfig<Notification, NotificationResponse>.NewConfig();
        }
    }
}

using eDoktor.Model.Requests;
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
            TypeAdapterConfig<Country, CountryResponse>.NewConfig();
            TypeAdapterConfig<City, CityResponse>.NewConfig()
                .Map(dest => dest.CountryName, src => src.Country != null ? src.Country.Name : string.Empty);
            // The Country navigation is never set from a request; only the CountryId FK is.
            TypeAdapterConfig<CityUpsertRequest, City>.NewConfig().Ignore(dest => dest.Country);
            TypeAdapterConfig<Clinic, ClinicResponse>.NewConfig()
                .Map(dest => dest.CityName, src => src.City != null ? src.City.Name : null);
            TypeAdapterConfig<Notification, NotificationResponse>.NewConfig();
            // Updating a clinic without new coordinates keeps the stored ones instead of wiping them.
            TypeAdapterConfig<ClinicUpsertRequest, Clinic>.NewConfig().IgnoreNullValues(true);
        }
    }
}

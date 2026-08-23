using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.Clinics
{
    public interface IClinicService : ICRUDService<ClinicResponse, ClinicSearchObject, ClinicUpsertRequest, ClinicUpsertRequest> { }
}

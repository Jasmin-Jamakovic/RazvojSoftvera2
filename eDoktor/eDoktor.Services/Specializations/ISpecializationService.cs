using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;

namespace eDoktor.Services.Specializations
{
    public interface ISpecializationService : ICRUDService<SpecializationResponse, SpecializationSearchObject, SpecializationUpsertRequest, SpecializationUpsertRequest> { }
}

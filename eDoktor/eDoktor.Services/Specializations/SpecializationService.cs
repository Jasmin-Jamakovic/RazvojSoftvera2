using System.Linq;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using MapsterMapper;

namespace eDoktor.Services.Specializations
{
    public class SpecializationService :
        BaseCRUDService<SpecializationResponse, SpecializationSearchObject, Specialization, SpecializationUpsertRequest, SpecializationUpsertRequest>,
        ISpecializationService
    {
        public SpecializationService(eDoktorDbContext db, IMapper mapper) : base(db, mapper) { }

        protected override System.Linq.IQueryable<Specialization> ApplyFilter(System.Linq.IQueryable<Specialization> query, SpecializationSearchObject s)
        {
            query = base.ApplyFilter(query, s);
            if (!string.IsNullOrWhiteSpace(s.Name))
                query = query.Where(x => x.Name.Contains(s.Name));
            return query;
        }
    }
}

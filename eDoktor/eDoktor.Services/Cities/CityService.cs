using System.Linq;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using MapsterMapper;

namespace eDoktor.Services.Cities
{
    public class CityService :
        BaseCRUDService<CityResponse, CitySearchObject, City, CityUpsertRequest, CityUpsertRequest>,
        ICityService
    {
        public CityService(eDoktorDbContext db, IMapper mapper) : base(db, mapper) { }

        protected override System.Linq.IQueryable<City> ApplyFilter(System.Linq.IQueryable<City> query, CitySearchObject s)
        {
            query = base.ApplyFilter(query, s);
            if (!string.IsNullOrWhiteSpace(s.Name))
                query = query.Where(x => x.Name.Contains(s.Name));
            return query.OrderBy(x => x.Name);
        }
    }
}

using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using MapsterMapper;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.Cities
{
    public class CityService :
        BaseCRUDService<CityResponse, CitySearchObject, City, CityUpsertRequest, CityUpsertRequest>,
        ICityService
    {
        public CityService(eDoktorDbContext db, IMapper mapper) : base(db, mapper) { }

        public override async Task<CityResponse> CreateAsync(CityUpsertRequest request)
        {
            await EnsureCountryExistsAsync(request.CountryId);
            var created = await base.CreateAsync(request);
            return (await GetByIdAsync(created.Id))!;
        }

        public override async Task<CityResponse> UpdateAsync(int id, CityUpsertRequest request)
        {
            await EnsureCountryExistsAsync(request.CountryId);
            await base.UpdateAsync(id, request);
            return (await GetByIdAsync(id))!;
        }

        public override async Task<CityResponse?> GetByIdAsync(int id)
        {
            var entity = await _context.Cities.Include(c => c.Country).FirstOrDefaultAsync(c => c.Id == id && !c.IsDeleted);
            return entity == null ? null : MapToResponse(entity);
        }

        private async Task EnsureCountryExistsAsync(int countryId)
        {
            if (!await _context.Countries.AnyAsync(c => c.Id == countryId && !c.IsDeleted))
                throw new UserException("Odabrana država ne postoji.");
        }

        protected override IQueryable<City> ApplyFilter(IQueryable<City> query, CitySearchObject s)
        {
            query = base.ApplyFilter(query, s).Include(x => x.Country);
            if (!string.IsNullOrWhiteSpace(s.Name))
                query = query.Where(x => x.Name.Contains(s.Name));
            if (s.CountryId.HasValue)
                query = query.Where(x => x.CountryId == s.CountryId.Value);
            return query.OrderBy(x => x.Name);
        }
    }
}

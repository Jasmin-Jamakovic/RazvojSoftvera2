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

namespace eDoktor.Services.Countries
{
    public class CountryService :
        BaseCRUDService<CountryResponse, CountrySearchObject, Country, CountryUpsertRequest, CountryUpsertRequest>,
        ICountryService
    {
        public CountryService(eDoktorDbContext db, IMapper mapper) : base(db, mapper) { }

        public override async Task<CountryResponse> CreateAsync(CountryUpsertRequest request)
        {
            await EnsureUniqueNameAsync(request.Name, null);
            return await base.CreateAsync(request);
        }

        public override async Task<CountryResponse> UpdateAsync(int id, CountryUpsertRequest request)
        {
            await EnsureUniqueNameAsync(request.Name, id);
            return await base.UpdateAsync(id, request);
        }

        public override async Task<bool> DeleteAsync(int id)
        {
            if (await _context.Cities.AnyAsync(c => c.CountryId == id))
                throw new UserException("Država se ne može obrisati jer je koriste gradovi.");
            return await base.DeleteAsync(id);
        }

        private async Task EnsureUniqueNameAsync(string name, int? exceptId)
        {
            var trimmed = name.Trim();
            if (await _context.Countries.AnyAsync(c => c.Name == trimmed && c.Id != exceptId))
                throw new UserException("Država sa tim nazivom već postoji.");
        }

        protected override IQueryable<Country> ApplyFilter(IQueryable<Country> query, CountrySearchObject s)
        {
            query = base.ApplyFilter(query, s);
            if (!string.IsNullOrWhiteSpace(s.Name))
                query = query.Where(x => x.Name.Contains(s.Name));
            return query.OrderBy(x => x.Name);
        }
    }
}

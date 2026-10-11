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

namespace eDoktor.Services.Clinics
{
    public class ClinicService :
        BaseCRUDService<ClinicResponse, ClinicSearchObject, Clinic, ClinicUpsertRequest, ClinicUpsertRequest>,
        IClinicService
    {
        public ClinicService(eDoktorDbContext db, IMapper mapper) : base(db, mapper) { }

        public override async Task<ClinicResponse> CreateAsync(ClinicUpsertRequest request)
        {
            await EnsureCityExistsAsync(request.CityId);
            return await base.CreateAsync(request);
        }

        public override async Task<ClinicResponse> UpdateAsync(int id, ClinicUpsertRequest request)
        {
            await EnsureCityExistsAsync(request.CityId);
            return await base.UpdateAsync(id, request);
        }

        private async Task EnsureCityExistsAsync(int? cityId)
        {
            if (cityId == null || !await _context.Cities.AnyAsync(c => c.Id == cityId.Value))
                throw new UserException("Odabrani grad ne postoji.");
        }

        protected override System.Linq.IQueryable<Clinic> ApplyFilter(System.Linq.IQueryable<Clinic> query, ClinicSearchObject s)
        {
            query = base.ApplyFilter(query, s).Include(x => x.City);
            if (!string.IsNullOrWhiteSpace(s.Name)) query = query.Where(x => x.Name.Contains(s.Name));
            if (s.CityId.HasValue) query = query.Where(x => x.CityId == s.CityId.Value);
            return query;
        }
    }
}

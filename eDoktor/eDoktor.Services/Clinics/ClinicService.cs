using System.Linq;
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

        protected override System.Linq.IQueryable<Clinic> ApplyFilter(System.Linq.IQueryable<Clinic> query, ClinicSearchObject s)
        {
            query = base.ApplyFilter(query, s).Include(x => x.City);
            if (!string.IsNullOrWhiteSpace(s.Name)) query = query.Where(x => x.Name.Contains(s.Name));
            if (s.CityId.HasValue) query = query.Where(x => x.CityId == s.CityId.Value);
            return query;
        }
    }
}

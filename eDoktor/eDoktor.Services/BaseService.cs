using System.Linq;
using Microsoft.EntityFrameworkCore;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Database;
using MapsterMapper;

namespace eDoktor.Services
{
    public abstract class BaseService<T, TSearch, TEntity> : IService<T, TSearch>
        where T : class
        where TSearch : BaseSearchObject
        where TEntity : class
    {
        protected readonly eDoktorDbContext _context;
        protected readonly IMapper _mapper;

        public BaseService(eDoktorDbContext context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        public virtual async Task<PagedResult<T>> GetAsync(TSearch search)
        {
            search.Normalize();

            var query = _context.Set<TEntity>().AsQueryable();
            query = ApplyFilter(query, search);

            int? totalCount = null;
            if (search.IncludeTotalCount)
            {
                totalCount = await query.CountAsync();
            }

            query = query.Skip(search.Page!.Value * search.PageSize!.Value)
                         .Take(search.PageSize!.Value);

            var list = await query.ToListAsync();

            return new PagedResult<T>
            {
                Items = list.Select(MapToResponse).ToList(),
                TotalCount = totalCount
            };
        }

        protected virtual T MapToResponse(TEntity entity)
            => _mapper.Map<T>(entity);

        public virtual async Task<T?> GetByIdAsync(int id)
        {
            var entity = await _context.Set<TEntity>().FindAsync(id);
            if (entity == null) return null;

            var isDeleted = typeof(TEntity).GetProperty("IsDeleted");
            if (isDeleted != null && isDeleted.PropertyType == typeof(bool) && (bool)isDeleted.GetValue(entity)!)
                return null;

            return MapToResponse(entity);
        }

        protected virtual IQueryable<TEntity> ApplyFilter(IQueryable<TEntity> query, TSearch search)
        {
            if (search.IncludeDeleted) return query;
            var isDeleted = typeof(TEntity).GetProperty("IsDeleted");
            if (isDeleted == null || isDeleted.PropertyType != typeof(bool)) return query;

            var param = System.Linq.Expressions.Expression.Parameter(typeof(TEntity), "e");
            var prop = System.Linq.Expressions.Expression.Property(param, "IsDeleted");
            var not = System.Linq.Expressions.Expression.Equal(prop, System.Linq.Expressions.Expression.Constant(false));
            var lambda = System.Linq.Expressions.Expression.Lambda<System.Func<TEntity, bool>>(not, param);
            return query.Where(lambda);
        }
    }
}

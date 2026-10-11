using eDoktor.Model;
using eDoktor.Model.Requests;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using MapsterMapper;
namespace eDoktor.Services
{
    public abstract class BaseCRUDService<T, TSearch, TEntity, TInsert, TUpdate> : BaseService<T, TSearch, TEntity>, ICRUDService<T, TSearch, TInsert, TUpdate> where T : class where TSearch : BaseSearchObject where TEntity : class, new() where TInsert : class where TUpdate : class
    {
        public BaseCRUDService(eDoktorDbContext context, IMapper mapper): base(context, mapper)
        {
        }

        public virtual async Task<T> CreateAsync(TInsert request){

            var entity = new TEntity();
            MapInsertToEntity(entity, request);
            _context.Set<TEntity>().Add(entity);

            await _context.SaveChangesAsync();
            return MapToResponse(entity);
        }

        protected virtual TEntity MapInsertToEntity(TEntity entity, TInsert request){
            return _mapper.Map(request, entity);
        }

        public virtual async Task<T> UpdateAsync(int id, TUpdate request){
            var entity = await _context.Set<TEntity>().FindAsync(id);
            if (entity == null){
                throw new NotFoundException("Entity not found");
            }

            MapUpdateToEntity(entity, request);

            await _context.SaveChangesAsync();
            return MapToResponse(entity);
        }

        protected virtual void MapUpdateToEntity(TEntity entity, TUpdate request){
            _mapper.Map(request, entity);
        }

        public virtual async Task<bool> DeleteAsync(int id){
            var entity = await _context.Set<TEntity>().FindAsync(id);
            if (entity == null){
                return false;
            }

            _context.Set<TEntity>().Remove(entity);
            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException ex)
            {
                // FK Restrict tripped: the record is still referenced elsewhere. Surface a clear
                // reason instead of a generic 500 (spec §3.1: "prikazati jasnu poruku o razlogu").
                throw new UserException("Zapis se ne može obrisati jer se koristi u drugim podacima.", ex);
            }
            return true;
        }

        public virtual async Task<bool> SoftDeleteAsync(int id)
        {
            var entity = await _context.Set<TEntity>().FindAsync(id);
            if (entity == null)
                return false;

            var isDeletedProperty = typeof(TEntity).GetProperty("IsDeleted");
            if (isDeletedProperty != null && isDeletedProperty.PropertyType == typeof(bool))
            {
                isDeletedProperty.SetValue(entity, true);
                await _context.SaveChangesAsync();
                return true;
            }

            return false;
        }

        public virtual async Task<bool> RestoreAsync(int id)
        {
            var entity = await _context.Set<TEntity>().FindAsync(id);
            if (entity == null)
                return false;

            var isDeletedProperty = typeof(TEntity).GetProperty("IsDeleted");
            if (isDeletedProperty != null && isDeletedProperty.PropertyType == typeof(bool))
            {
                isDeletedProperty.SetValue(entity, false);
                await _context.SaveChangesAsync();
                return true;
            }

            return false;
        }

    }
} 
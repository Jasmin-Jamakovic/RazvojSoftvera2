    using eDoktor.Services.Database;
    using System.Collections.Generic;
    using System.Threading.Tasks;
    using eDoktor.Model.Responses;
    using eDoktor.Model.Requests;
    using eDoktor.Model.SearchObjects;

    
    namespace eDoktor.Services
    {
        public interface ICRUDService<T, TSearch, TInsert, TUpdate> : IService<T, TSearch> where T : class where TSearch : BaseSearchObject where TInsert : class where TUpdate : class
        {
            Task<T> CreateAsync(TInsert request);
            Task<T> UpdateAsync(int id, TUpdate request);
            Task<bool> DeleteAsync(int id);
            Task<bool> SoftDeleteAsync(int id);
            Task<bool> RestoreAsync(int id);
        }
    }
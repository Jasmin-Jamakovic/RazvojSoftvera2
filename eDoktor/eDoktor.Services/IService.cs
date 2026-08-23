    using eDoktor.Services.Database;
    using System.Collections.Generic;
    using System.Threading.Tasks;
    using eDoktor.Model.Responses;
    using eDoktor.Model.Requests;
    using eDoktor.Model.SearchObjects;

    
    namespace eDoktor.Services
    {
        public interface IService<T, TSearch> where T : class where TSearch : BaseSearchObject
        {
            Task<PagedResult<T>> GetAsync(TSearch search);
            Task<T?> GetByIdAsync(int id);
        }
    }
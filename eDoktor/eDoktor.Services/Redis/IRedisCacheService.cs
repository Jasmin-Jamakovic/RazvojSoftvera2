using System;
using System.Threading.Tasks;

namespace eDoktor.Services.Redis
{
    public interface IRedisCacheService
    {
        Task<T?> GetAsync<T>(string key);
        Task SetAsync<T>(string key, T value, TimeSpan ttl);
        Task RemoveAsync(string key);
    }
}

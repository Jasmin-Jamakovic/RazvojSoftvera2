using System;
using System.Threading.Tasks;
using Newtonsoft.Json;
using StackExchange.Redis;

namespace eDoktor.Services.Redis
{
    // No-op fallback used when Redis is not configured; lets the app boot without Redis.
    public class NullRedisCacheService : IRedisCacheService
    {
        public Task<T?> GetAsync<T>(string key) => Task.FromResult<T?>(default);
        public Task SetAsync<T>(string key, T value, TimeSpan ttl) => Task.CompletedTask;
        public Task RemoveAsync(string key) => Task.CompletedTask;
    }

    public class RedisCacheService : IRedisCacheService
    {
        private readonly IConnectionMultiplexer _mux;
        public RedisCacheService(IConnectionMultiplexer mux) { _mux = mux; }

        private IDatabase Db => _mux.GetDatabase();

        public async Task<T?> GetAsync<T>(string key)
        {
            var v = await Db.StringGetAsync(key);
            if (v.IsNullOrEmpty) return default;
            return JsonConvert.DeserializeObject<T>(v!);
        }

        public Task SetAsync<T>(string key, T value, TimeSpan ttl)
            => Db.StringSetAsync(key, JsonConvert.SerializeObject(value), ttl);

        public Task RemoveAsync(string key) => Db.KeyDeleteAsync(key);
    }
}

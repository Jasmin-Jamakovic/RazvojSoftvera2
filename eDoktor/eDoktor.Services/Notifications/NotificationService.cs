using System.Linq;
using System.Threading.Tasks;
using eDoktor.Model.Responses;
using eDoktor.Model.SearchObjects;
using eDoktor.Services.Database;
using eDoktor.Services.Database.Entities;
using eDoktor.Services.SignalR;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace eDoktor.Services.Notifications
{
    public class NotificationService : INotificationService
    {
        private readonly eDoktorDbContext _db;
        private readonly IHubContext<NotificationHub> _hub;
        public NotificationService(eDoktorDbContext db, IHubContext<NotificationHub> hub) { _db = db; _hub = hub; }

        public async Task<PagedResult<NotificationResponse>> GetAsync(NotificationSearchObject s)
        {
            var q = _db.Notifications.AsQueryable();
            if (s.UserId.HasValue) q = q.Where(n => n.UserId == s.UserId.Value);
            if (s.IsRead.HasValue) q = q.Where(n => n.IsRead == s.IsRead.Value);
            q = q.OrderByDescending(n => n.CreatedAt);

            s.Normalize();
            int? total = s.IncludeTotalCount ? await q.CountAsync() : null;
            q = q.Skip(s.Page!.Value * s.PageSize!.Value).Take(s.PageSize!.Value);

            var list = await q.ToListAsync();
            return new PagedResult<NotificationResponse>
            {
                Items = list.Select(Map).ToList(),
                TotalCount = total
            };
        }

        public async Task<NotificationResponse> SendAsync(int userId, string title, string body, string type = "general")
        {
            var n = new Notification { UserId = userId, Title = title, Body = body, Type = type };
            _db.Notifications.Add(n);
            await _db.SaveChangesAsync();

            var dto = Map(n);
            await _hub.Clients.Group($"user-{userId}").SendAsync("notification:new", dto);
            return dto;
        }

        public async Task<bool> MarkAsReadAsync(int id, int userId)
        {
            var n = await _db.Notifications.FirstOrDefaultAsync(x => x.Id == id && x.UserId == userId);
            if (n == null) return false;
            n.IsRead = true;
            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<int> MarkAllAsReadAsync(int userId)
        {
            var ns = await _db.Notifications.Where(n => n.UserId == userId && !n.IsRead).ToListAsync();
            foreach (var n in ns) n.IsRead = true;
            await _db.SaveChangesAsync();
            return ns.Count;
        }

        private static NotificationResponse Map(Notification n) => new()
        {
            Id = n.Id, UserId = n.UserId, Title = n.Title, Body = n.Body, Type = n.Type, IsRead = n.IsRead, CreatedAt = n.CreatedAt
        };
    }
}

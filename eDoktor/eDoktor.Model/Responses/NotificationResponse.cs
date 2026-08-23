using System;

namespace eDoktor.Model.Responses
{
    public class NotificationResponse
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Body { get; set; } = string.Empty;
        public string Type { get; set; } = "general";
        public bool IsRead { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}

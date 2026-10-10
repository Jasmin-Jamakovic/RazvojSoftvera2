using System;

namespace eDoktor.Model.Responses
{
    public class ConsultationMessageResponse
    {
        public int Id { get; set; }
        public int AppointmentId { get; set; }
        public int SenderId { get; set; }
        public string SenderName { get; set; } = string.Empty;
        public string? Text { get; set; }
        // The photo itself is served by GET .../messages/{id}/image so lists carry no blobs.
        public bool HasImage { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}

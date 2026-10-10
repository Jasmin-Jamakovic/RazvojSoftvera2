using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class ConsultationMessageRequest
    {
        [MaxLength(2000, ErrorMessage = "Poruka smije imati najviše 2000 znakova.")]
        public string? Text { get; set; }

        // Optional photo (PNG/JPEG/GIF/WEBP, max 5 MB), sent as base64 in JSON like profile photos.
        public byte[]? Image { get; set; }
    }
}

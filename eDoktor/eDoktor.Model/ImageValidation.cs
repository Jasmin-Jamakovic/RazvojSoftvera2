namespace eDoktor.Model
{
    // Validates uploaded images by their magic bytes (not just a claimed extension) and
    // sniffs the content type for serving. Used by upload validation and the photo endpoints.
    public static class ImageValidation
    {
        public const long MaxBytes = 5 * 1024 * 1024; // 5 MB

        /// Returns the content type detected from the file's magic bytes, or null if it is
        /// not one of the supported image formats.
        public static string? DetectContentType(byte[]? bytes)
        {
            if (bytes == null || bytes.Length < 12) return null;

            // PNG: 89 50 4E 47 0D 0A 1A 0A
            if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47)
                return "image/png";
            // JPEG: FF D8 FF
            if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF)
                return "image/jpeg";
            // GIF: "GIF8"
            if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38)
                return "image/gif";
            // WEBP: "RIFF"...."WEBP"
            if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
                bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50)
                return "image/webp";

            return null;
        }

        public static bool IsValidImage(byte[]? bytes)
            => bytes != null && bytes.Length <= MaxBytes && DetectContentType(bytes) != null;
    }
}

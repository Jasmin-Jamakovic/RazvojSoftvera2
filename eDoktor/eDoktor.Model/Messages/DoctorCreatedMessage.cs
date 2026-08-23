namespace eDoktor.Model.Messages
{
    public class DoctorCreatedMessage
    {
        public int UserId { get; set; }
        public string Email { get; set; } = string.Empty;
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string Username { get; set; } = string.Empty;
        public string TemporaryPassword { get; set; } = string.Empty;
    }
}

namespace eDoktor.Model.Requests
{
    // Shared input formats, kept identical to the client-side validators.
    public static class ValidationPatterns
    {
        public const string Phone = @"^\+?[0-9 ()\-]{6,20}$";
        public const string PhoneMessage = "Unesite ispravan broj telefona (npr. +387 61 123 456).";
        public const string Gender = "^[MF]$";
        public const string GenderMessage = "Spol mora biti M ili F.";
        public const string BloodType = @"^(0|A|B|AB)[+-]$";
        public const string BloodTypeMessage = "Krvna grupa mora biti npr. A+, 0-, AB+.";
        public const string EmailMessage = "Unesite ispravnu email adresu (npr. ime@domena.com).";
    }
}

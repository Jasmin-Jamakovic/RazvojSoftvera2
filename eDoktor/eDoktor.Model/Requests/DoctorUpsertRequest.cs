using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace eDoktor.Model.Requests
{
    public class DoctorUpsertRequest
    {
        // On insert: full user info to create the linked doctor account.
        // On update: only profile/clinic/bio/specializations are taken from this DTO.
        [Required, MaxLength(50)] public string FirstName { get; set; } = string.Empty;
        [Required, MaxLength(50)] public string LastName { get; set; } = string.Empty;
        public string? Username { get; set; }
        [EmailAddress] public string? Email { get; set; }
        public string? PhoneNumber { get; set; }

        [Required] public int ClinicId { get; set; }
        public string? Bio { get; set; }
        public int YearsExperience { get; set; }
        public decimal ConsultationPrice { get; set; }
        public byte[]? ProfilePhoto { get; set; }

        public List<int> SpecializationIds { get; set; } = new();
    }
}

namespace eDoktor.Model.SearchObjects
{
    /// Paging + free-text filter for the lists inside a medical record (visits, prescriptions, lab results).
    public class MedicalRecordSearchObject : BaseSearchObject
    {
        /// Matches the diagnosis (visits), a medication (prescriptions) or the title (lab results).
        public string? Search { get; set; }
    }
}

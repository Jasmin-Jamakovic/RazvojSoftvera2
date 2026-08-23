namespace eDoktor.Model
{
    // Central place for role names so they are not scattered as magic strings (spec §3.4).
    // Values must match the seeded Role.Name values in the database.
    public static class Roles
    {
        public const string Admin = "admin";
        public const string Doctor = "doctor";
        public const string Patient = "patient";

        // Combined lists for [Authorize(Roles = ...)] (attribute arguments must be constants).
        public const string AdminOrDoctor = "admin,doctor";
    }
}

using System;

namespace eDoktor.Model
{
    // Times are stored in UTC; texts shown to people (notifications, emails) use the clinic's time zone,
    // configured once via App__TimeZone (e.g. Europe/Sarajevo).
    public static class DisplayTime
    {
        private static readonly TimeZoneInfo Zone = TimeZoneInfo.FindSystemTimeZoneById(
            Environment.GetEnvironmentVariable("App__TimeZone")
            ?? throw new InvalidOperationException("App__TimeZone is not configured (set it in .env)."));

        public static DateTime ToLocal(DateTime utc) =>
            TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), Zone);

        /// Clinic local time -> UTC (e.g. seeded working hours "09:00" in Sarajevo).
        public static DateTime ToUtc(DateTime local) =>
            TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(local, DateTimeKind.Unspecified), Zone);

        /// "13.10.2026. 10:00" in the clinic's local time.
        public static string Format(DateTime utc) => ToLocal(utc).ToString("dd.MM.yyyy. HH:mm");
    }
}

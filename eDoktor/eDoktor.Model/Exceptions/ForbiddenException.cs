using System;

namespace eDoktor.Model
{
    /// <summary>
    /// Thrown when an authenticated user attempts an action they are not allowed to perform
    /// (e.g. editing another user's data). Mapped to HTTP 403 by the ExceptionFilter.
    /// </summary>
    public class ForbiddenException : Exception
    {
        public ForbiddenException(string message) : base(message) { }
    }
}

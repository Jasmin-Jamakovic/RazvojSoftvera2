using System;

namespace eDoktor.Model
{
    /// <summary>
    /// Thrown when a requested entity does not exist. Mapped to HTTP 404 by the ExceptionFilter.
    /// </summary>
    public class NotFoundException : Exception
    {
        public NotFoundException(string message) : base(message) { }
    }
}

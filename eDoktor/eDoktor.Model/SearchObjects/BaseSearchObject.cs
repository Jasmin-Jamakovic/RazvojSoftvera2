using System;

namespace eDoktor.Model.SearchObjects
{
    public class BaseSearchObject
    {
        /// <summary>Hard upper bound on how many rows a single list request may return.</summary>
        public const int MaxPageSize = 100;
        /// <summary>Page size applied when the client does not specify one.</summary>
        public const int DefaultPageSize = 20;

        public int? Page { get; set; }
        public int? PageSize { get; set; }
        public bool IncludeTotalCount { get; set; } = true;
        public bool IncludeDeleted { get; set; } = false;

        /// <summary>
        /// Forces every list query into a bounded page: defaults a missing page/size and clamps
        /// PageSize to [1, MaxPageSize] so no endpoint can ever return an entire table (DoS guard).
        /// Call this at the start of every GetAsync before applying Skip/Take.
        /// </summary>
        public void Normalize()
        {
            Page ??= 0;
            if (Page < 0) Page = 0;
            PageSize = Math.Clamp(PageSize ?? DefaultPageSize, 1, MaxPageSize);
        }
    }
}

// Copyright (c) One Identity LLC. All rights reserved.

namespace ServiceNowTicketValidator.DTOs
{
    using System.Collections.Generic;
    using System.Diagnostics.CodeAnalysis;

    [SuppressMessage("ReSharper", "InconsistentNaming")]
    internal class ServiceNowResult<T> where T : class
    {
        public IEnumerable<T> result { get; set; }
    }
}

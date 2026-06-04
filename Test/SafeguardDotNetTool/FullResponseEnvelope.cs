// Copyright (c) One Identity LLC. All rights reserved.

namespace SafeguardDotNetTool;

using System.Collections.Generic;

/// <summary>
/// Output envelope for the --full mode, exposing status code, headers, and body.
/// </summary>
internal sealed class FullResponseEnvelope
{
    /// <summary>
    /// Gets or sets the HTTP status code.
    /// </summary>
    public int StatusCode { get; set; }

    /// <summary>
    /// Gets or sets the response headers.
    /// </summary>
    public IDictionary<string, string> Headers { get; set; }

    /// <summary>
    /// Gets or sets the raw response body.
    /// </summary>
    public string Body { get; set; }
}

// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet;

using System;
using System.Net;
using System.Text.Json;

/// <summary>
/// This class extends the base Exception class with a SafeguardDotNet specific exception.
/// SafeguardDotNet tries to throw all exception using this class. SafeguardDotNet throws
/// exceptions when 1) it fails to make call, 2) fails to parse or handle data, 3) when a
/// Safeguard API endpoint returns a non-success status code. When response data is
/// available, it is populated in the Response property in this class.
/// </summary>
public class SafeguardDotNetException : Exception
{
    public SafeguardDotNetException()
        : base("Unknown SafeguardDotNetException")
    {
    }

    public SafeguardDotNetException(string message)
        : base(message)
    {
    }

    public SafeguardDotNetException(string message, Exception innerException)
        : base(message, innerException)
    {
    }

    public SafeguardDotNetException(string message, HttpStatusCode httpStatusCode, string response)
        : base(message)
    {
        HttpStatusCode = httpStatusCode;
        Response = response;
        if (!string.IsNullOrEmpty(Response))
        {
            try
            {
                using var doc = JsonDocument.Parse(Response);
                var root = doc.RootElement;

                if (root.ValueKind == JsonValueKind.Object)
                {
                    if (root.TryGetProperty("Code", out var codeEl)
                        && int.TryParse(codeEl.ToString(), out var code))
                    {
                        ErrorCode = code;
                    }

                    if (root.TryGetProperty("Message", out var messageEl))
                    {
                        ErrorMessage = messageEl.ToString();
                    }

                    // Sps provides an "error" json object containing details
                    if (root.TryGetProperty("error", out var errorEl))
                    {
                        ErrorMessage = errorEl.ToString();
                    }
                }
            }
            catch (JsonException)
            {
                ErrorMessage = response;
            }
        }
    }

    /// <summary>
    /// HTTP status code returned from Safeguard API as part of the failure.
    /// </summary>
    public HttpStatusCode? HttpStatusCode { get; }

    /// <summary>
    /// Safeguard error code returned from Safeguard API as part of the failure.
    /// </summary>
    public int? ErrorCode { get; }

    /// <summary>
    /// Safeguard error code returned from Safeguard API as part of the failure.
    /// </summary>
    public string ErrorMessage { get; }

    /// <summary>
    /// Response data returned from Safeguard API as part of the failure.
    /// </summary>
    public string Response { get; }

    /// <summary>
    /// Whether or not this exception contains response data.
    /// </summary>
    public bool HasResponse => Response != null;
}

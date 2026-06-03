// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.Serialization;

/// <summary>
/// Internal DTO for deserializing the rSTS token exchange response.
/// </summary>
internal sealed class LoginResponse
{
    /// <summary>
    /// Gets or sets the response status (e.g., "Success").
    /// </summary>
    public string Status { get; set; }

    /// <summary>
    /// Gets or sets the user access token returned by the login endpoint.
    /// </summary>
    public string UserToken { get; set; }
}

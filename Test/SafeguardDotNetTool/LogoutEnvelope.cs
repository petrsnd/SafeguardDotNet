// Copyright (c) One Identity LLC. All rights reserved.

namespace SafeguardDotNetTool;

/// <summary>
/// Output envelope returned after logout, exposing the final access token.
/// </summary>
internal sealed class LogoutEnvelope
{
    /// <summary>
    /// Gets or sets the access token that was just invalidated.
    /// </summary>
    public string AccessToken { get; set; }

    /// <summary>
    /// Gets or sets a value indicating whether logout completed.
    /// </summary>
    public bool LoggedOut { get; set; }
}

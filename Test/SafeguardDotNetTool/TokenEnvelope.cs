// Copyright (c) One Identity LLC. All rights reserved.

namespace SafeguardDotNetTool;

/// <summary>
/// Output envelope exposing the current access token.
/// </summary>
internal sealed class TokenEnvelope
{
    /// <summary>
    /// Gets or sets the access token.
    /// </summary>
    public string AccessToken { get; set; }
}

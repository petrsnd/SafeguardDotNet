// Copyright (c) One Identity LLC. All rights reserved.

namespace SafeguardDotNetTool;

/// <summary>
/// Output envelope reporting remaining access token lifetime in seconds.
/// </summary>
internal sealed class TokenLifetimeEnvelope
{
    /// <summary>
    /// Gets or sets the remaining lifetime, in seconds.
    /// </summary>
    public int TokenLifetimeRemaining { get; set; }
}

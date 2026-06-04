// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.DeviceCodeLogin.Serialization;

using System.Text.Json.Serialization;

/// <summary>
/// Request body for the rSTS device authorization endpoint
/// (POST /RSTS/oauth2/DeviceLogin).
/// </summary>
internal sealed class DeviceAuthRequest
{
    /// <summary>
    /// Gets or sets the OAuth2 client identifier. May be empty; rSTS normalizes
    /// an empty value to its built-in ApplicationClientId.
    /// </summary>
    [JsonPropertyName("client_id")]
    public string ClientId { get; set; }

    /// <summary>
    /// Gets or sets the OAuth2 scope (e.g. "rsts:sts:primaryproviderid:local").
    /// </summary>
    [JsonPropertyName("scope")]
    public string Scope { get; set; }
}

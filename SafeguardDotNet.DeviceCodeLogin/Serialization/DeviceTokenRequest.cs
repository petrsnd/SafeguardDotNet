// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.DeviceCodeLogin.Serialization;

using System.Text.Json.Serialization;

/// <summary>
/// Request body for the rSTS token endpoint when polling for device-code
/// redemption (POST /RSTS/oauth2/token with the device_code grant type).
/// </summary>
internal sealed class DeviceTokenRequest
{
    /// <summary>
    /// Gets or sets the OAuth2 grant type. For the device authorization grant
    /// this is "urn:ietf:params:oauth:grant-type:device_code".
    /// </summary>
    [JsonPropertyName("grant_type")]
    public string GrantType { get; set; }

    /// <summary>
    /// Gets or sets the device code returned by the device authorization endpoint.
    /// </summary>
    [JsonPropertyName("device_code")]
    public string DeviceCode { get; set; }

    /// <summary>
    /// Gets or sets the OAuth2 client identifier. May be empty; see rSTS notes
    /// in <see cref="DeviceCodeLogin"/>.
    /// </summary>
    [JsonPropertyName("client_id")]
    public string ClientId { get; set; }
}

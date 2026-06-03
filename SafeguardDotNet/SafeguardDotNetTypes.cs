// Copyright (c) One Identity LLC. All rights reserved.

#pragma warning disable SA1649 // File name should match first type name
namespace OneIdentity.SafeguardDotNet;

using System;
using System.Collections.Generic;
using System.Net;
using System.Security;

using OneIdentity.SafeguardDotNet.Serialization;

/// <summary>
/// Service identifiers for the different services in the Safeguard API.
/// </summary>
public enum Service
{
    /// <summary>
    /// The core service contains all general cluster-wide Safeguard operations.
    /// </summary>
    Core,

    /// <summary>
    /// The appliance service contains appliance-specific Safeguard operations.
    /// </summary>
    Appliance,

    /// <summary>
    /// The notification service contains unauthenticated Safeguard operations.
    /// </summary>
    Notification,

    /// <summary>
    /// The a2a service contains application integration Safeguard operations.  It is called via the Safeguard.A2A class.
    /// </summary>
    A2A,

    /// <summary>
    /// The Management service contains unauthenticated endpoints for disaster-recovery and support operations. On hardware
    /// it is bound to the MGMT network interface. For on-prem VM it is unavailable except through the Kiosk app. On cloud
    /// VM it is listening on port 9337 and should be firewalled appropriately to restrict access.
    /// </summary>
    Management,
}

/// <summary>
/// A limited list of methods supported by the Safeguard API. Not all HTTP methods are supported.
/// </summary>
public enum Method
{
    /// <summary>
    /// HTTP POST method.
    /// </summary>
    Post,

    /// <summary>
    /// HTTP GET method.
    /// </summary>
    Get,

    /// <summary>
    /// HTTP PUT method.
    /// </summary>
    Put,

    /// <summary>
    /// HTTP DELETE method.
    /// </summary>
    Delete,
}

/// <summary>
/// A simple class for returning extended information from a Safeguard API method call.
/// </summary>
public class FullResponse
{
    public HttpStatusCode StatusCode { get; set; }

    public IDictionary<string, string> Headers { get; set; }

    public string Body { get; set; }
}

/// <summary>
/// A list of private key formats supported by Safeguard.
/// </summary>
public enum KeyFormat
{
    /// <summary>
    /// OpenSSH legacy PEM format
    /// </summary>
    OpenSsh,

    /// <summary>
    /// Tectia format for use with tools from SSH.com
    /// </summary>
    Ssh2,

    /// <summary>
    /// Putty format for use with PuTTY tools
    /// </summary>
    Putty,
}

/// <summary>
/// A class representing an API key secret.
/// </summary>
public class ApiKeySecret : IDisposable
{
    private bool _disposed;

    public int Id { get; set; }

    public string Name { get; set; }

    public string Description { get; set; }

    public string ClientId { get; set; }

    [System.Text.Json.Serialization.JsonConverter(typeof(SecureStringJsonConverter))]
    public SecureString ClientSecret { get; set; }

    public string ClientSecretId { get; set; }

    public override string ToString()
    {
        return SafeguardJson.Serialize(this);
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    protected virtual void Dispose(bool disposing)
    {
        if (_disposed || !disposing)
        {
            return;
        }

        ClientSecret?.Dispose();
        ClientSecret = null;
        _disposed = true;
    }
}

/// <summary>
/// A class representing the asset accounts that can be used with A2A credential retrieval.
/// </summary>
public class A2ARetrievableAccount : IDisposable
{
    private bool _disposed;

    public string ApplicationName { get; set; }

    public string Description { get; set; }

    [System.Text.Json.Serialization.JsonPropertyName("AccountDisabled")]
    [System.Text.Json.Serialization.JsonConverter(typeof(BoolIntJsonConverter))]
    public bool Disabled { get; set; }

    [System.Text.Json.Serialization.JsonConverter(typeof(SecureStringJsonConverter))]
    public SecureString ApiKey { get; set; }

    public int AssetId { get; set; }

    public string AssetName { get; set; }

    [System.Text.Json.Serialization.JsonPropertyName("NetworkAddress")]
    public string AssetNetworkAddress { get; set; }

    public string AssetDescription { get; set; }

    public int AccountId { get; set; }

    public string AccountName { get; set; }

    public string DomainName { get; set; }

    public string AccountType { get; set; }

    public string AccountDescription { get; set; }

    public override string ToString()
    {
        return SafeguardJson.Serialize(this);
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    protected virtual void Dispose(bool disposing)
    {
        if (_disposed || !disposing)
        {
            return;
        }

        ApiKey?.Dispose();
        ApiKey = null;
        _disposed = true;
    }
}

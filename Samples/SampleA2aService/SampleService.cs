// Copyright (c) One Identity LLC. All rights reserved.

namespace SampleA2aService;

using System;
using System.Collections.Generic;
using System.Configuration;
using System.Globalization;
using System.Linq;
using System.Security;
using System.Text.Json;

using OneIdentity.SafeguardDotNet;
using OneIdentity.SafeguardDotNet.A2A;
using OneIdentity.SafeguardDotNet.Event;

using Serilog;

internal class SampleService
{
    private readonly string _safeguardAddress;
    private readonly string _safeguardClientCertificateThumbprint;
    private readonly int _safeguardApiVersion;
    private readonly bool _safeguardIgnoreSsl;

    private ISafeguardConnection _connection;
    private ISafeguardA2AContext _a2AContext;
    private readonly List<ISafeguardEventListener> _listeners = new List<ISafeguardEventListener>();

    private sealed class MonitoredPassword
    {
        public SecureString ApiKey { get; set; }

        public string AssetName { get; set; }

        public string AccountName { get; set; }

        public override string ToString() => $"{AssetName}/{AccountName}";
    }

    private readonly List<MonitoredPassword> _monitoredPasswords = new List<MonitoredPassword>();

    public SampleService()
    {
        _safeguardAddress =
            ConfigUtils.ReadRequiredSettingFromAppConfig("SafeguardAddress", "Safeguard appliance network address");
        _safeguardClientCertificateThumbprint =
            ConfigUtils.ReadRequiredSettingFromAppConfig("SafeguardClientCertificateThumbprint",
                "Safeguard client certificate thumbprint").ToUpper(CultureInfo.InvariantCulture);
        _safeguardApiVersion =
            int.Parse(ConfigUtils.ReadRequiredSettingFromAppConfig("SafeguardApiVersion", "Safeguard API version"), CultureInfo.InvariantCulture);
        _safeguardIgnoreSsl = bool.Parse(ConfigurationManager.AppSettings["SafeguardIgnoreSsl"]);
    }

    private void GetApiKeysFromA2ARegistrations()
    {
        // optionally you can have Safeguard look up all A2A registrations for a given certificate user thumbprint
        // currently this requires auditor permission, but we will enhance A2A to include read ability without it
        try
        {
            var a2AJson = _connection.InvokeMethod(Service.Core, Method.Get, "A2ARegistrations", parameters: new Dictionary<string, string>
            {
                { "filter", $"CertificateUserThumbprint ieq '{_safeguardClientCertificateThumbprint}'" },
            });
            using var a2ADoc = JsonDocument.Parse(a2AJson);
            foreach (var a2A in a2ADoc.RootElement.EnumerateArray())
            {
                var id = a2A.GetProperty("Id").ToString();
                var credsJson = _connection.InvokeMethod(Service.Core, Method.Get, $"A2ARegistrations/{id}/RetrievableAccounts");
                using var credsDoc = JsonDocument.Parse(credsJson);
                foreach (var cred in credsDoc.RootElement.EnumerateArray())
                {
                    _monitoredPasswords.Add(new MonitoredPassword
                    {
                        ApiKey = (cred.TryGetProperty("ApiKey", out var akEl) ? akEl.GetString() : string.Empty).ToSecureString(),
                        AssetName = cred.TryGetProperty("SystemName", out var snEl) ? snEl.GetString() : null,
                        AccountName = cred.TryGetProperty("AccountName", out var anEl) ? anEl.GetString() : null,
                    });
                }
            }
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException("Unable to get API keys using certificate user, did you grant auditor permissions?", ex);
        }
    }

    private void PasswordChangeHandler(string eventName, string eventBody)
    {
        var eventInfo = JsonSerializer.Deserialize<MonitoredPassword>(eventBody);
        Log.Information("Password changed for {MonitoredPassword}", eventInfo);

        // NOTE: eventInfo won't have the API key field filled out because that isn't in the eventBody Json
        //       You can look up in the list of _monitoredPasswords to find the API key

        try
        {
            var apiKey = _monitoredPasswords.Single(mp => mp.AssetName == eventInfo.AssetName && mp.AccountName == eventInfo.AccountName).ApiKey;
            using var password = _a2AContext.RetrievePassword(apiKey);
            // TODO: Add useful code here to do something with the fetched password

            // Also, note that the password you get back is a SecureString.  In order to turn it back into a regular string
            // you can use the provided convenience function:

            // password.ToInsecureString()
        }
#pragma warning disable CA1031 // Intentional top-level catch-all for error logging
        catch (Exception ex)
#pragma warning restore CA1031
        {
            Log.Information(ex, "Password not in monitored list for handled event {MonitoredPassword}", eventInfo);
        }
    }

    private void StartListener(MonitoredPassword monitored)
    {
        Log.Information("Startling listener for {MonitoredPassword}", monitored);
        var listener = _a2AContext.GetPersistentA2AEventListener(monitored.ApiKey, PasswordChangeHandler);
        listener.Start();
        _listeners.Add(listener);
    }

    public void Start()
    {
        ConfigUtils.CheckForDebugHook();

        // connect to Safeguard
        _connection = Safeguard.Connect(
            _safeguardAddress,
            _safeguardClientCertificateThumbprint,
            _safeguardApiVersion,
            _safeguardIgnoreSsl);
        _a2AContext = Safeguard.A2A.GetContext(
            _safeguardAddress,
            _safeguardClientCertificateThumbprint,
            _safeguardApiVersion,
            _safeguardIgnoreSsl);

        // figure out what API keys to monitor
        GetApiKeysFromA2ARegistrations();
        if (_monitoredPasswords.Count == 0)
        {
            throw new InvalidOperationException("No API keys found in A2A registrations.  Nothing to do.");
        }

        Log.Information("Found {MonitoredPasswordCount} API keys to monitor for password changes", _monitoredPasswords.Count);

        // start the listeners
        foreach (var monitored in _monitoredPasswords)
        {
            StartListener(monitored);
        }
    }

    public void Stop()
    {
        // shut everything down
        foreach (var listener in _listeners)
        {
            listener?.Stop();
            listener?.Dispose();
        }

        _connection?.Dispose();
        _a2AContext?.Dispose();
    }
}

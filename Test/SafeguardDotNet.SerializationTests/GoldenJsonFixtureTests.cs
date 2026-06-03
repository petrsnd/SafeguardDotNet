// Copyright (c) One Identity LLC. All rights reserved.

namespace SafeguardDotNet.SerializationTests;

using System;
using System.IO;
using System.Security;
using System.Text.Json;

using OneIdentity.SafeguardDotNet;
using OneIdentity.SafeguardDotNet.A2A;
using OneIdentity.SafeguardDotNet.Event;
using OneIdentity.SafeguardDotNet.Serialization;

using Xunit;

public class GoldenJsonFixtureTests
{
    private static string LoadFixture(string name) =>
        File.ReadAllText(Path.Combine("Fixtures", name));

    // ─── LoginResponse DTO ───────────────────────────────────────────────────

    [Fact]
    public void LoginResponse_Deserializes_Success()
    {
        var json = LoadFixture("login-response.json");
        var result = SafeguardJson.Deserialize<LoginResponse>(json);

        Assert.Equal("Success", result.Status);
        Assert.NotNull(result.UserToken);
        Assert.StartsWith("eyJ", result.UserToken);
    }

    [Fact]
    public void LoginResponse_Deserializes_OnlyStatusAndUserToken()
    {
        // LoginResponse only has Status and UserToken; extra properties are ignored
        var json = LoadFixture("login-response.json");
        var result = SafeguardJson.Deserialize<LoginResponse>(json);

        Assert.Equal("Success", result.Status);
        Assert.NotNull(result.UserToken);
    }

    // ─── A2ARetrievableAccount DTO ───────────────────────────────────────────

    [Fact]
    public void A2ARetrievableAccount_Deserializes_EnabledAccount()
    {
        var json = LoadFixture("a2a-retrievable-account.json");
        var account = SafeguardJson.Deserialize<A2ARetrievableAccount>(json);

        Assert.Equal(42, account.AccountId);
        Assert.Equal("svc_backup", account.AccountName);
        Assert.Equal("test.local", account.DomainName);
        Assert.Equal(10, account.AssetId);
        Assert.Equal("server01", account.AssetName);
        Assert.Equal("192.168.1.100", account.AssetNetworkAddress);
        Assert.False(account.Disabled); // AccountDisabled: 0 → false
        Assert.NotNull(account.ApiKey);
        Assert.Equal("a1b2c3d4-e5f6-7890-abcd-ef1234567890", SecureStringToString(account.ApiKey));
    }

    [Fact]
    public void A2ARetrievableAccount_Deserializes_DisabledAccount()
    {
        var json = LoadFixture("a2a-retrievable-account-disabled.json");
        var account = SafeguardJson.Deserialize<A2ARetrievableAccount>(json);

        Assert.Equal(99, account.AccountId);
        Assert.Equal("admin_locked", account.AccountName);
        Assert.True(account.Disabled); // AccountDisabled: 1 → true
        Assert.Null(account.ApiKey); // null in JSON → null SecureString
    }

    [Fact]
    public void A2ARetrievableAccount_Serializes_BoolAsInt()
    {
        var account = new A2ARetrievableAccount
        {
            AccountId = 1,
            AccountName = "test",
            Disabled = true,
            AssetNetworkAddress = "10.0.0.1",
        };

        var json = SafeguardJson.Serialize(account);
        using var doc = JsonDocument.Parse(json);

        // Disabled → AccountDisabled (property name mapping)
        Assert.True(doc.RootElement.TryGetProperty("AccountDisabled", out var disabledEl));
        Assert.Equal(JsonValueKind.Number, disabledEl.ValueKind);
        Assert.Equal(1, disabledEl.GetInt32());

        // AssetNetworkAddress → NetworkAddress (property name mapping)
        Assert.True(doc.RootElement.TryGetProperty("NetworkAddress", out var netEl));
        Assert.Equal("10.0.0.1", netEl.GetString());
    }

    [Fact]
    public void A2ARetrievableAccount_Serializes_FalseDisabledAsZero()
    {
        var account = new A2ARetrievableAccount
        {
            AccountId = 2,
            AccountName = "test2",
            Disabled = false,
        };

        var json = SafeguardJson.Serialize(account);
        using var doc = JsonDocument.Parse(json);

        Assert.True(doc.RootElement.TryGetProperty("AccountDisabled", out var disabledEl));
        Assert.Equal(0, disabledEl.GetInt32());
    }

    // ─── BrokeredAccessRequest DTO ───────────────────────────────────────────

    [Fact]
    public void BrokeredAccessRequest_Deserializes_PasswordType()
    {
        var json = LoadFixture("brokered-access-request-password.json");
        var request = SafeguardJson.Deserialize<BrokeredAccessRequest>(json);

        Assert.Equal(BrokeredAccessRequestType.Password, request.AccessType);
        Assert.Equal("admin@test.local", request.ForUserName);
        Assert.Equal(1, request.ForUserId);
        Assert.Equal("Local", request.ForUserIdentityProvider);
        Assert.Equal(10, request.AssetId);
        Assert.Equal("server01", request.AssetName);
        Assert.Equal(42, request.AccountId);
        Assert.Equal("svc_backup", request.AccountName);
        Assert.False(request.IsEmergency);
        Assert.Equal(new DateTime(2024, 1, 15, 8, 30, 0, DateTimeKind.Utc), request.RequestedFor);
        Assert.Equal(new TimeSpan(0, 2, 30, 0), request.RequestedDuration);
    }

    [Fact]
    public void BrokeredAccessRequest_Deserializes_SshType()
    {
        var json = LoadFixture("brokered-access-request-ssh.json");
        var request = SafeguardJson.Deserialize<BrokeredAccessRequest>(json);

        Assert.Equal(BrokeredAccessRequestType.Ssh, request.AccessType);
        Assert.Equal("ops@test.local", request.ForUserName);
        Assert.True(request.IsEmergency);
        Assert.Equal(new TimeSpan(1, 0, 0, 0), request.RequestedDuration); // 1:0:0 = 1 day, 0 hours, 0 min
    }

    [Fact]
    public void BrokeredAccessRequest_Deserializes_RdpType()
    {
        var json = LoadFixture("brokered-access-request-rdp.json");
        var request = SafeguardJson.Deserialize<BrokeredAccessRequest>(json);

        Assert.Equal(BrokeredAccessRequestType.Rdp, request.AccessType);
        Assert.Equal("helpdesk@test.local", request.ForUserName);
        Assert.Equal(new TimeSpan(0, 8, 0, 0), request.RequestedDuration); // 0:8:0 = 0 days, 8 hours, 0 min
    }

    [Fact]
    public void BrokeredAccessRequest_Serializes_AccessTypeAsExpectedString()
    {
        var request = new BrokeredAccessRequest
        {
            AccessType = BrokeredAccessRequestType.Password,
            ForUserName = "user1",
            AssetId = 1,
            AccountId = 2,
        };

        var json = SafeguardJson.Serialize(request);
        using var doc = JsonDocument.Parse(json);
        Assert.Equal("Password", doc.RootElement.GetProperty("AccessType").GetString());
    }

    [Fact]
    public void BrokeredAccessRequest_Serializes_SshAccessType()
    {
        var request = new BrokeredAccessRequest { AccessType = BrokeredAccessRequestType.Ssh };
        var json = SafeguardJson.Serialize(request);
        using var doc = JsonDocument.Parse(json);
        Assert.Equal("SSH", doc.RootElement.GetProperty("AccessType").GetString());
    }

    [Fact]
    public void BrokeredAccessRequest_Serializes_RdpAccessType()
    {
        var request = new BrokeredAccessRequest { AccessType = BrokeredAccessRequestType.Rdp };
        var json = SafeguardJson.Serialize(request);
        using var doc = JsonDocument.Parse(json);
        Assert.Equal("RemoteDesktop", doc.RootElement.GetProperty("AccessType").GetString());
    }

    [Fact]
    public void BrokeredAccessRequest_Serializes_UtcDateTime()
    {
        var request = new BrokeredAccessRequest
        {
            AccessType = BrokeredAccessRequestType.Password,
            RequestedFor = new DateTime(2024, 1, 15, 8, 30, 0, DateTimeKind.Utc),
        };

        var json = SafeguardJson.Serialize(request);
        using var doc = JsonDocument.Parse(json);
        Assert.Equal("2024-01-15 08:30:00Z", doc.RootElement.GetProperty("RequestedFor").GetString());
    }

    [Fact]
    public void BrokeredAccessRequest_Serializes_CustomTimeSpan()
    {
        var request = new BrokeredAccessRequest
        {
            AccessType = BrokeredAccessRequestType.Password,
            RequestedDuration = new TimeSpan(0, 2, 30, 0), // 0 days, 2 hours, 30 min
        };

        var json = SafeguardJson.Serialize(request);
        using var doc = JsonDocument.Parse(json);
        Assert.Equal("0:2:30", doc.RootElement.GetProperty("RequestedDuration").GetString());
    }

    [Fact]
    public void BrokeredAccessRequest_Serializes_ForProviderPropertyName()
    {
        var request = new BrokeredAccessRequest
        {
            AccessType = BrokeredAccessRequestType.Password,
            ForUserIdentityProvider = "ActiveDirectory",
        };

        var json = SafeguardJson.Serialize(request);
        using var doc = JsonDocument.Parse(json);
        // C# property ForUserIdentityProvider maps to wire name ForProvider
        Assert.True(doc.RootElement.TryGetProperty("ForProvider", out var el));
        Assert.Equal("ActiveDirectory", el.GetString());
    }

    // ─── SecureString Converter ──────────────────────────────────────────────

    [Fact]
    public void ApiKeySecret_Serializes_SecureStringAsPlainText()
    {
        var secret = new ApiKeySecret
        {
            Id = 1,
            Name = "TestKey",
            ClientId = "client-123",
            ClientSecret = MakeSecureString("super-secret-value"),
        };

        var json = SafeguardJson.Serialize(secret);
        using var doc = JsonDocument.Parse(json);
        Assert.Equal("super-secret-value", doc.RootElement.GetProperty("ClientSecret").GetString());
    }

    [Fact]
    public void ApiKeySecret_Deserializes_StringToSecureString()
    {
        var json = @"{""Id"":1,""Name"":""Key"",""ClientId"":""c1"",""ClientSecret"":""mysecret""}";
        var secret = SafeguardJson.Deserialize<ApiKeySecret>(json);

        Assert.NotNull(secret.ClientSecret);
        Assert.Equal("mysecret", SecureStringToString(secret.ClientSecret));
        Assert.True(secret.ClientSecret.IsReadOnly());
    }

    [Fact]
    public void ApiKeySecret_Deserializes_NullSecureString()
    {
        var json = @"{""Id"":1,""Name"":""Key"",""ClientId"":""c1"",""ClientSecret"":null}";
        var secret = SafeguardJson.Deserialize<ApiKeySecret>(json);

        Assert.Null(secret.ClientSecret);
    }

    // ─── Event Parsing ───────────────────────────────────────────────────────

    [Fact]
    public void ParseEvents_Normal_ExtractsNameAndBody()
    {
        var json = LoadFixture("event-envelope-normal.json");
        var events = EventHandlerRegistry.ParseEvents(json);

        Assert.Single(events);
        Assert.Equal("AssetCreated", events[0].Name);
        Assert.Contains("\"Id\":42", events[0].Body);
        Assert.Contains("\"NewServer\"", events[0].Body);
    }

    [Fact]
    public void ParseEvents_MissingName_ReturnsNullName()
    {
        var json = LoadFixture("event-envelope-missing-name.json");
        var events = EventHandlerRegistry.ParseEvents(json);

        Assert.Single(events);
        Assert.Null(events[0].Name);
        Assert.Contains("PasswordChanged", events[0].Body);
    }

    [Fact]
    public void ParseEvents_MissingData_ReturnsNullBody()
    {
        var json = LoadFixture("event-envelope-missing-data.json");
        var events = EventHandlerRegistry.ParseEvents(json);

        Assert.Single(events);
        Assert.Equal("PolicyModified", events[0].Name);
        Assert.Null(events[0].Body);
    }

    [Fact]
    public void ParseEvents_NumericName_UsesEventNameFromData()
    {
        var json = LoadFixture("event-envelope-numeric-name.json");
        var events = EventHandlerRegistry.ParseEvents(json);

        Assert.Single(events);
        // Numeric "12345" triggers workaround: uses Data.EventName instead
        Assert.Equal("LegacyPasswordCheck", events[0].Name);
    }

    [Fact]
    public void ParseEvents_MalformedJson_ReturnsEmpty()
    {
        var events = EventHandlerRegistry.ParseEvents("not json at all");
        Assert.Empty(events);
    }

    [Fact]
    public void ParseEvents_EmptyString_ReturnsEmpty()
    {
        var events = EventHandlerRegistry.ParseEvents(string.Empty);
        Assert.Empty(events);
    }

    // ─── Error Response Parsing ──────────────────────────────────────────────

    [Fact]
    public void SafeguardJson_Parse_SppErrorResponse()
    {
        var json = LoadFixture("spp-error-response.json");
        using var doc = SafeguardJson.Parse(json);
        var root = doc.RootElement;

        Assert.Equal(60094, root.GetProperty("Code").GetInt32());
        Assert.Equal("Authorization is denied for this request.", root.GetProperty("Message").GetString());
    }

    [Fact]
    public void SafeguardJson_Parse_RstsErrorResponse()
    {
        var json = LoadFixture("rsts-error-response.json");
        using var doc = SafeguardJson.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("invalid_request", root.GetProperty("error").GetString());
        Assert.Equal("Access denied.", root.GetProperty("error_description").GetString());
        Assert.False(root.GetProperty("success").GetBoolean());
    }

    // ─── rSTS Token Response ─────────────────────────────────────────────────

    [Fact]
    public void SafeguardJson_Parse_RstsTokenResponse()
    {
        var json = LoadFixture("rsts-token-response.json");
        using var doc = SafeguardJson.Parse(json);
        var root = doc.RootElement;

        Assert.True(root.TryGetProperty("access_token", out var tokenEl));
        Assert.StartsWith("eyJ", tokenEl.GetString());
        Assert.Equal(299, root.GetProperty("expires_in").GetInt32());
        Assert.Equal("Bearer", root.GetProperty("token_type").GetString());
        Assert.True(root.GetProperty("success").GetBoolean());
    }

    // ─── Generic JSON Parsing (appliance responses) ──────────────────────────

    [Fact]
    public void SafeguardJson_Parse_MeResponse_HasExpectedProperties()
    {
        var json = LoadFixture("spp-me-response.json");
        using var doc = SafeguardJson.Parse(json);
        var root = doc.RootElement;

        Assert.Equal(1, root.GetProperty("Id").GetInt32());
        Assert.Equal("Admin", root.GetProperty("UserName").GetString());
        Assert.Equal(JsonValueKind.Array, root.GetProperty("AdminRoles").ValueKind);
        Assert.False(root.GetProperty("Disabled").GetBoolean());
    }

    [Fact]
    public void SafeguardJson_Parse_AuthProviders_IsArray()
    {
        var json = LoadFixture("spp-auth-providers-response.json");
        using var doc = SafeguardJson.Parse(json);
        var root = doc.RootElement;

        Assert.Equal(JsonValueKind.Array, root.ValueKind);
        Assert.Equal(2, root.GetArrayLength());
        Assert.Equal("Local", root[0].GetProperty("Name").GetString());
        Assert.Equal("Certificate", root[1].GetProperty("Name").GetString());
    }

    [Fact]
    public void SafeguardJson_Parse_StatusResponse()
    {
        var json = LoadFixture("spp-status-response.json");
        using var doc = SafeguardJson.Parse(json);
        var root = doc.RootElement;

        Assert.Equal("Online", root.GetProperty("ApplianceCurrentState").GetString());
        Assert.True(root.GetProperty("IsPrimary").GetBoolean());
    }

    // ─── Round-Trip Tests ────────────────────────────────────────────────────

    [Fact]
    public void BrokeredAccessRequest_RoundTrip_PreservesAllValues()
    {
        var original = new BrokeredAccessRequest
        {
            AccessType = BrokeredAccessRequestType.Ssh,
            ForUserName = "user@domain.com",
            ForUserIdentityProvider = "AD",
            ForUserId = 42,
            AssetName = "linux-server",
            AssetId = 100,
            AccountName = "root",
            AccountId = 200,
            AccountAssetName = "linux-server",
            IsEmergency = true,
            RequestedFor = new DateTime(2024, 6, 15, 10, 0, 0, DateTimeKind.Utc),
            RequestedDuration = new TimeSpan(2, 4, 0, 0), // 2 days, 4 hours
        };

        var json = SafeguardJson.Serialize(original);
        var deserialized = SafeguardJson.Deserialize<BrokeredAccessRequest>(json);

        Assert.Equal(original.AccessType, deserialized.AccessType);
        Assert.Equal(original.ForUserName, deserialized.ForUserName);
        Assert.Equal(original.ForUserIdentityProvider, deserialized.ForUserIdentityProvider);
        Assert.Equal(original.ForUserId, deserialized.ForUserId);
        Assert.Equal(original.AssetName, deserialized.AssetName);
        Assert.Equal(original.AssetId, deserialized.AssetId);
        Assert.Equal(original.AccountName, deserialized.AccountName);
        Assert.Equal(original.AccountId, deserialized.AccountId);
        Assert.Equal(original.IsEmergency, deserialized.IsEmergency);
        Assert.Equal(original.RequestedFor, deserialized.RequestedFor);
        Assert.Equal(original.RequestedDuration, deserialized.RequestedDuration);
    }

    [Fact]
    public void A2ARetrievableAccount_RoundTrip_PreservesValues()
    {
        var original = new A2ARetrievableAccount
        {
            AccountId = 5,
            AccountName = "svc",
            AssetId = 10,
            AssetName = "host",
            AssetNetworkAddress = "10.0.0.5",
            DomainName = "corp.local",
            Disabled = true,
            ApiKey = MakeSecureString("my-api-key"),
        };

        var json = SafeguardJson.Serialize(original);
        var deserialized = SafeguardJson.Deserialize<A2ARetrievableAccount>(json);

        Assert.Equal(original.AccountId, deserialized.AccountId);
        Assert.Equal(original.AccountName, deserialized.AccountName);
        Assert.Equal(original.AssetId, deserialized.AssetId);
        Assert.Equal(original.AssetName, deserialized.AssetName);
        Assert.Equal(original.AssetNetworkAddress, deserialized.AssetNetworkAddress);
        Assert.Equal(original.DomainName, deserialized.DomainName);
        Assert.Equal(original.Disabled, deserialized.Disabled);
        Assert.Equal("my-api-key", SecureStringToString(deserialized.ApiKey));
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static SecureString MakeSecureString(string value)
    {
        var ss = new SecureString();
        foreach (var c in value)
        {
            ss.AppendChar(c);
        }

        ss.MakeReadOnly();
        return ss;
    }

    private static string SecureStringToString(SecureString value)
    {
        var ptr = System.Runtime.InteropServices.Marshal.SecureStringToBSTR(value);
        try
        {
            return System.Runtime.InteropServices.Marshal.PtrToStringBSTR(ptr);
        }
        finally
        {
            System.Runtime.InteropServices.Marshal.ZeroFreeBSTR(ptr);
        }
    }
}

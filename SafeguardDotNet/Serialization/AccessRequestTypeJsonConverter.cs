// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.Serialization;

using System;
using System.Text.Json;
using System.Text.Json.Serialization;

using OneIdentity.SafeguardDotNet.A2A;

/// <summary>
/// Converts <see cref="BrokeredAccessRequestType"/> to/from the Safeguard API string representation.
/// Maps: Password ↔ "Password", Ssh ↔ "SSH", Rdp ↔ "RemoteDesktop".
/// </summary>
internal sealed class AccessRequestTypeJsonConverter : JsonConverter<BrokeredAccessRequestType>
{
    public override BrokeredAccessRequestType Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var value = reader.GetString();

        if (string.Equals(value, "Password", StringComparison.OrdinalIgnoreCase))
        {
            return BrokeredAccessRequestType.Password;
        }

        if (string.Equals(value, "SSH", StringComparison.OrdinalIgnoreCase))
        {
            return BrokeredAccessRequestType.Ssh;
        }

        if (string.Equals(value, "RemoteDesktop", StringComparison.OrdinalIgnoreCase))
        {
            return BrokeredAccessRequestType.Rdp;
        }

        throw new SafeguardDotNetException($"Unknown access request type \"{value}\"");
    }

    public override void Write(Utf8JsonWriter writer, BrokeredAccessRequestType value, JsonSerializerOptions options)
    {
        switch (value)
        {
            case BrokeredAccessRequestType.Password:
                writer.WriteStringValue("Password");
                break;
            case BrokeredAccessRequestType.Ssh:
                writer.WriteStringValue("SSH");
                break;
            case BrokeredAccessRequestType.Rdp:
                writer.WriteStringValue("RemoteDesktop");
                break;
            default:
                throw new SafeguardDotNetException($"Unknown access request type \"{value}\"");
        }
    }
}

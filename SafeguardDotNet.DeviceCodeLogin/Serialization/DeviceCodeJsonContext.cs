// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.DeviceCodeLogin.Serialization;

using System.Text.Json.Serialization;

/// <summary>
/// Source-generated JSON serializer context for the DeviceCodeLogin package.
/// Guarantees AOT-compatible, reflection-free serialization at compile time.
/// </summary>
[JsonSerializable(typeof(DeviceAuthRequest))]
[JsonSerializable(typeof(DeviceTokenRequest))]
internal partial class DeviceCodeJsonContext : JsonSerializerContext
{
}

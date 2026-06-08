// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.Serialization;

using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

using OneIdentity.SafeguardDotNet.A2A;

/// <summary>
/// Source-generated JSON serializer context for all types that require serialization in the SDK.
/// Guarantees AOT-compatible, reflection-free serialization at compile time.
/// </summary>
[JsonSourceGenerationOptions(PropertyNameCaseInsensitive = true)]

// BCL / framework types
[JsonSerializable(typeof(string))]
[JsonSerializable(typeof(Dictionary<string, string>))]
[JsonSerializable(typeof(JsonElement))]

// Authentication / connection DTOs
[JsonSerializable(typeof(LoginResponse))]
[JsonSerializable(typeof(JoinRequest))]

// A2A DTOs
[JsonSerializable(typeof(A2ARegistration))]
[JsonSerializable(typeof(A2ARetrievableAccount))]
[JsonSerializable(typeof(ApiKeySecret))]
[JsonSerializable(typeof(BrokeredAccessRequest))]
[JsonSerializable(typeof(SshKey))]

// A2A list shapes
[JsonSerializable(typeof(List<A2ARegistration>))]
[JsonSerializable(typeof(List<A2ARetrievableAccount>))]
[JsonSerializable(typeof(List<ApiKeySecret>))]
internal partial class SafeguardJsonContext : JsonSerializerContext
{
}

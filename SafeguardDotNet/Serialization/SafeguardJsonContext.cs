// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.Serialization;

using System.Collections.Generic;
using System.Text.Json.Serialization;

using OneIdentity.SafeguardDotNet.A2A;

/// <summary>
/// Source-generated JSON serializer context for all types that require serialization in the SDK.
/// Guarantees AOT-compatible, reflection-free serialization at compile time.
/// </summary>
[JsonSerializable(typeof(BrokeredAccessRequest))]
[JsonSerializable(typeof(A2ARetrievableAccount))]
[JsonSerializable(typeof(ApiKeySecret))]
[JsonSerializable(typeof(LoginResponse))]
[JsonSerializable(typeof(Dictionary<string, string>))]
internal partial class SafeguardJsonContext : JsonSerializerContext
{
}

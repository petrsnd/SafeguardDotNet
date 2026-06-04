// Copyright (c) One Identity LLC. All rights reserved.

namespace SafeguardDotNetTool;

using System.Text.Json.Serialization;

/// <summary>
/// Source-generated JSON serializer context for tool output envelopes.
/// </summary>
[JsonSourceGenerationOptions(WriteIndented = false)]
[JsonSerializable(typeof(TokenLifetimeEnvelope))]
[JsonSerializable(typeof(LogoutEnvelope))]
[JsonSerializable(typeof(TokenEnvelope))]
[JsonSerializable(typeof(FullResponseEnvelope))]
internal partial class ToolJsonContext : JsonSerializerContext
{
}

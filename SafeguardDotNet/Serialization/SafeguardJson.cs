// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.Serialization;

using System;
using System.Text.Json;
using System.Text.Json.Serialization.Metadata;

/// <summary>
/// Centralized facade for all JSON serialization/deserialization in the SDK.
/// All calls go through the source-generated <see cref="SafeguardJsonContext"/> to guarantee
/// AOT-compatible, reflection-free serialization.
/// </summary>
internal static class SafeguardJson
{
    /// <summary>
    /// Serializes a value using the source-generated context.
    /// </summary>
    /// <typeparam name="T">The type to serialize.</typeparam>
    /// <param name="value">The value to serialize.</param>
    /// <returns>A JSON string representation of the value.</returns>
    public static string Serialize<T>(T value)
    {
        return JsonSerializer.Serialize(value, GetTypeInfo<T>());
    }

    /// <summary>
    /// Deserializes JSON into the specified type using the source-generated context.
    /// Throws <see cref="SafeguardDotNetException"/> if the input is empty or deserializes to null,
    /// so callers fail with an actionable error instead of an opaque <see cref="NullReferenceException"/>.
    /// </summary>
    /// <typeparam name="T">The type to deserialize into.</typeparam>
    /// <param name="json">The JSON string to deserialize.</param>
    /// <returns>The deserialized object.</returns>
    public static T Deserialize<T>(string json)
    {
        if (string.IsNullOrWhiteSpace(json))
        {
            throw new SafeguardDotNetException(
                $"Cannot deserialize empty response into {typeof(T).Name}.");
        }

        var result = JsonSerializer.Deserialize(json, GetTypeInfo<T>());
        return result ?? throw new SafeguardDotNetException(
            $"Deserialization of {typeof(T).Name} produced null. Response body: {json}");
    }

    /// <summary>
    /// Parses a JSON string into a <see cref="JsonDocument"/>.
    /// The caller is responsible for disposing the returned document.
    /// </summary>
    /// <param name="json">The JSON string to parse.</param>
    /// <returns>A parsed <see cref="JsonDocument"/>.</returns>
    public static JsonDocument Parse(string json) => JsonDocument.Parse(json);

    private static JsonTypeInfo<T> GetTypeInfo<T>()
    {
        return SafeguardJsonContext.Default.GetTypeInfo(typeof(T)) is JsonTypeInfo<T> typeInfo
            ? typeInfo
            : throw new InvalidOperationException(
                $"Type {typeof(T).Name} is not registered in {nameof(SafeguardJsonContext)}.");
    }
}

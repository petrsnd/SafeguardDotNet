// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.Serialization;

using System;
using System.Text.Json;
using System.Text.Json.Serialization;

/// <summary>
/// Converts <see cref="bool"/> to/from integer representation (1/0) as used by the Safeguard API.
/// Also handles string representations ("1"/"0") on read.
/// </summary>
internal sealed class BoolIntJsonConverter : JsonConverter<bool>
{
    public override bool Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        switch (reader.TokenType)
        {
            case JsonTokenType.Number:
                return reader.GetInt32() == 1;
            case JsonTokenType.String:
                return reader.GetString() == "1";
            case JsonTokenType.True:
                return true;
            case JsonTokenType.False:
                return false;
            default:
                throw new JsonException($"Unexpected token type {reader.TokenType} for bool property.");
        }
    }

    public override void Write(Utf8JsonWriter writer, bool value, JsonSerializerOptions options)
    {
        writer.WriteNumberValue(value ? 1 : 0);
    }
}

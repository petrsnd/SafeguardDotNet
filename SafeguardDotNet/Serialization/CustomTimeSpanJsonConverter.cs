// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.Serialization;

using System;
using System.Text.Json;
using System.Text.Json.Serialization;

/// <summary>
/// Converts <see cref="TimeSpan"/> to/from the "D:H:M" string format (e.g., "0:2:30" for 2 hours 30 minutes)
/// as expected by the Safeguard API.
/// </summary>
internal sealed class CustomTimeSpanJsonConverter : JsonConverter<TimeSpan>
{
    public override TimeSpan Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var value = reader.GetString();
        if (value == null)
        {
            return TimeSpan.Zero;
        }

        var fields = value.Split(':');
        if (fields.Length < 3)
        {
            throw new SafeguardDotNetException($"Unexpected timespan value \"{value}\"");
        }

        return new TimeSpan(int.Parse(fields[0]), int.Parse(fields[1]), int.Parse(fields[2]), 0);
    }

    public override void Write(Utf8JsonWriter writer, TimeSpan value, JsonSerializerOptions options)
    {
        writer.WriteStringValue($"{value.Days}:{value.Hours}:{value.Minutes}");
    }
}

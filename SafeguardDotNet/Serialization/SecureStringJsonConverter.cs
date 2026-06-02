// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.Serialization;

using System;
using System.Runtime.InteropServices;
using System.Security;
using System.Text.Json;
using System.Text.Json.Serialization;

/// <summary>
/// Converts <see cref="SecureString"/> to/from a plain JSON string value.
/// </summary>
internal sealed class SecureStringJsonConverter : JsonConverter<SecureString>
{
    public override SecureString Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var value = reader.GetString();
        var secureString = new SecureString();

        if (value != null)
        {
            foreach (var c in value)
            {
                secureString.AppendChar(c);
            }
        }

        secureString.MakeReadOnly();
        return secureString;
    }

    public override void Write(Utf8JsonWriter writer, SecureString value, JsonSerializerOptions options)
    {
        if (value == null)
        {
            writer.WriteNullValue();
            return;
        }

        IntPtr ptr = Marshal.SecureStringToBSTR(value);
        try
        {
            writer.WriteStringValue(Marshal.PtrToStringBSTR(ptr));
        }
        finally
        {
            Marshal.ZeroFreeBSTR(ptr);
        }
    }
}

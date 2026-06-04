// Copyright (c) One Identity LLC. All rights reserved.

namespace SafeguardDotNetPkceNoninteractiveLoginTester;

/// <summary>
/// Request body for a Safeguard setting value PUT.
/// </summary>
internal sealed class SettingValueRequest
{
    /// <summary>
    /// Gets or sets the setting value.
    /// </summary>
    public string Value { get; set; }
}

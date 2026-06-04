// Copyright (c) One Identity LLC. All rights reserved.

namespace SafeguardDotNetPkceNoninteractiveLoginTester;

/// <summary>
/// Output envelope describing the result of toggling the ResourceOwner grant type setting.
/// </summary>
internal sealed class GrantTypeSettingEnvelope
{
    /// <summary>
    /// Gets or sets the setting name.
    /// </summary>
    public string Setting { get; set; }

    /// <summary>
    /// Gets or sets the previous setting value.
    /// </summary>
    public string PreviousValue { get; set; }

    /// <summary>
    /// Gets or sets the new setting value.
    /// </summary>
    public string NewValue { get; set; }

    /// <summary>
    /// Gets or sets a value indicating whether ResourceOwner is enabled after the change.
    /// </summary>
    public bool ResourceOwnerEnabled { get; set; }
}

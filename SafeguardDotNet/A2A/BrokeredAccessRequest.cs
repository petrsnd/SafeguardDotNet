// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.A2A;

using System;

using OneIdentity.SafeguardDotNet.Serialization;

/// <summary>
/// Type of brokered access request to create.
/// </summary>
public enum BrokeredAccessRequestType
{
    /// <summary>
    /// Access request is for a password.
    /// </summary>
    Password,

    /// <summary>
    /// Access request is for an SSH session.
    /// </summary>
    Ssh,

    /// <summary>
    /// Access request is for a remote desktop session.
    /// </summary>
    Rdp,
}

/// <summary>
/// This class is used to define a brokered access request.
/// </summary>
public class BrokeredAccessRequest
{
    /// <summary>
    /// The type of access request to create.
    /// </summary>
    [System.Text.Json.Serialization.JsonConverter(typeof(AccessRequestTypeJsonConverter))]
    public BrokeredAccessRequestType AccessType { get; set; }

    /// <summary>
    /// The name of the user to create the access request for. If the <see cref="ForUserId"/> property is
    /// set, then this property will be ignored.
    /// </summary>
    public string ForUserName { get; set; }

    /// <summary>
    /// The name of the identity provider to create the access request for. If the <see cref="ForUserId"/>
    /// property is set, then this property will be ignored.
    /// </summary>
    [System.Text.Json.Serialization.JsonPropertyName("ForProvider")]
    public string ForUserIdentityProvider { get; set; }

    /// <summary>
    /// The ID of the user to create the access request for.
    /// </summary>
    public int? ForUserId { get; set; }

    /// <summary>
    /// The name of the asset to create the access request for. If the <see cref="AssetId"/> property is
    /// set, then this property will be ignored.
    /// </summary>
    public string AssetName { get; set; }

    /// <summary>
    /// The ID of the asset to create the access request for.
    /// </summary>
    public int? AssetId { get; set; }

    /// <summary>
    /// The name of the account to create the access request for. If the <see cref="AccountId"/> property is
    /// set, then this property will be ignored.
    /// </summary>
    public string AccountName { get; set; }

    /// <summary>
    /// The ID of the account to create the access request for.
    /// </summary>
    public int? AccountId { get; set; }

    /// <summary>
    /// The name of the asset the account is from to create the access request for. If the
    /// <see cref="AccountAssetId"/> property is set, then this property will be ignored.
    /// </summary>
    public string AccountAssetName { get; set; }

    /// <summary>
    /// The ID of the asset the account is from to create the access request for.
    /// </summary>
    public int? AccountAssetId { get; set; }

    /// <summary>
    /// Whether or not this is an emergency access request.
    /// </summary>
    public bool IsEmergency { get; set; }

    /// <summary>
    /// The name of the pre-defined reason code to include in the access request. If the <see cref="ReasonCodeId"/>
    /// property is set, then this property will be ignored.
    /// </summary>
    public string ReasonCode { get; set; }

    /// <summary>
    /// The ID of the pre-defined reason code to include in the access request.
    /// </summary>
    public int? ReasonCodeId { get; set; }

    /// <summary>
    /// A reason comment to include in the access request.
    /// </summary>
    public string ReasonComment { get; set; }

    /// <summary>
    /// A ticket number associated with the new access request.
    /// </summary>
    public string TicketNumber { get; set; }

    /// <summary>
    /// The time when the access request should be requested for. All values will be converted to UTC date and time
    /// before being sent to the server.
    /// </summary>
    [System.Text.Json.Serialization.JsonConverter(typeof(UtcDateTimeJsonConverter))]
    public DateTime? RequestedFor { get; set; }

    /// <summary>
    /// The amount of time the access request should be requested for.
    /// </summary>
    [System.Text.Json.Serialization.JsonConverter(typeof(CustomTimeSpanJsonConverter))]
    public TimeSpan? RequestedDuration { get; set; }

    public int? RequestedDurationDays => RequestedDuration?.Days;

    public int? RequestedDurationHours => RequestedDuration?.Hours;

    public int? RequestedDurationMinutes => RequestedDuration?.Minutes;
}

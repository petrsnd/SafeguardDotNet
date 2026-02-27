// Copyright (c) One Identity LLC. All rights reserved.

using System.Net.Http.Headers;
using System.Security;

namespace OneIdentity.SafeguardDotNet.Sps
{
    internal interface ISpsAuthenticator
    {
        string NetworkAddress { get; }

        string UserName { get; }

        SecureString Password { get; }

        bool IgnoreSsl { get; }

        AuthenticationHeaderValue GetAuthenticationHeader();
    }
}

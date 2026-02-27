// Copyright (c) One Identity LLC. All rights reserved.

using System.Runtime.Serialization;

namespace OneIdentity.SafeguardDotNet.Event
{
    public class SafeguardEventListenerDisconnectedException : SafeguardDotNetException
    {
        public SafeguardEventListenerDisconnectedException()
            : base("SafeguardEventListener has permanently disconnected SignalR connection")
        {
        }

        protected SafeguardEventListenerDisconnectedException
            (SerializationInfo info, StreamingContext context)
            : base(info, context)
        {
        }
    }
}

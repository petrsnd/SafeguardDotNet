// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.Event
{
    using System.Runtime.Serialization;

    public class SafeguardEventListenerDisconnectedException : SafeguardDotNetException
    {
        public SafeguardEventListenerDisconnectedException()
            : base("SafeguardEventListener has permanently disconnected SignalR connection")
        {
        }

        protected SafeguardEventListenerDisconnectedException(SerializationInfo info, StreamingContext context)
            : base(info, context)
        {
        }
    }
}

using System.Security;
using OneIdentity.SafeguardDotNet;
using OneIdentity.SafeguardDotNet.A2A;
using OneIdentity.SafeguardDotNet.Event;
using Spcw.Utils;

namespace Spcw.MetaDbAppPoolManager
{
    class ManagerService
    {
        private readonly SafeguardConnectionInfo _connectionInfo;
        private readonly SecureString _apiKey;
        private readonly string _accountName;

        private ISafeguardEventListener _eventListener;
        private ISafeguardA2AContext _a2AContext;

        public ManagerService()
        {
            _connectionInfo = Config.GetSafeguardConnectionInformation();
            _apiKey = Config.ReadRequiredSettingFromAppConfig("AccountApiKey",
                    "Safeguard A2A API key for retrieving account password").ToSecureString();
            _accountName = Config.ReadRequiredSettingFromAppConfig("AccountName",
                "Name of account corresponding to password");
        }

        private void HandlePasswordChange(string eventName, string eventBody)
        {
            // This will be called every time the password changes
            // Call to change password in metadb

            var currentPassword = _a2AContext.RetrievePassword(_apiKey);
        }

        public void Start()
        {
            _eventListener = Safeguard.A2A.Event.GetPersistentA2AEventListener(_apiKey, HandlePasswordChange,
                _connectionInfo.NetworkAddress, _connectionInfo.CertificateThumbprint, _connectionInfo.ApiVersion,
                _connectionInfo.IgnoreSsl);
            _a2AContext = Safeguard.A2A.GetContext(_connectionInfo.NetworkAddress,
                _connectionInfo.CertificateThumbprint, _connectionInfo.ApiVersion, _connectionInfo.IgnoreSsl);
            _eventListener.Start();
        }

        public void Stop()
        {
            _eventListener.Stop();
            _eventListener?.Dispose();
            _a2AContext?.Dispose();

            _eventListener = null;
            _a2AContext = null;
        }
    }
}

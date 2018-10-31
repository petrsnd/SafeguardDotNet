using System;
using System.Security;
using Newtonsoft.Json;
using OneIdentity.SafeguardDotNet;
using OneIdentity.SafeguardDotNet.A2A;
using OneIdentity.SafeguardDotNet.Event;
using Serilog;
using Spcw.Utils;

namespace Spcw.MetaDbAppPoolManager
{
    class ManagerService
    {
        private readonly SafeguardConnectionInfo _connectionInfo;
        private readonly SecureString _apiKey;
        private string _accountName;

        private ISafeguardEventListener _eventListener;
        private ISafeguardA2AContext _a2AContext;

        public ManagerService()
        {
            _connectionInfo = Config.GetSafeguardConnectionInformation();
            _apiKey = Config.ReadRequiredSettingFromAppConfig("AccountApiKey",
                    "Safeguard A2A API key for retrieving account password").ToSecureString();
        }

        private void ChangeAppPoolPassword(SecureString newPassword)
        {
            Log.Information("Changing App Pool Password for {Account}", _accountName);
            // Need to set password using _accountName, newPassword
        }

        private void HandlePasswordChange(string eventName, string eventBody)
        {
            if (string.IsNullOrEmpty(_accountName))
            {
                var definition = new {AccountName = ""};
                var eventData = JsonConvert.DeserializeAnonymousType(eventBody, definition);
                _accountName = eventData.AccountName;
                Log.Information("Using account name = {Account}", _accountName);
            }
            var newPassword = _a2AContext.RetrievePassword(_apiKey);
            ChangeAppPoolPassword(newPassword);
        }

        public void Start()
        {
            try
            {
                _eventListener = Safeguard.A2A.Event.GetPersistentA2AEventListener(_apiKey, HandlePasswordChange,
                    _connectionInfo.NetworkAddress, _connectionInfo.CertificateThumbprint, _connectionInfo.ApiVersion,
                    _connectionInfo.IgnoreSsl);
                _a2AContext = Safeguard.A2A.GetContext(_connectionInfo.NetworkAddress,
                    _connectionInfo.CertificateThumbprint, _connectionInfo.ApiVersion, _connectionInfo.IgnoreSsl);
                _eventListener.Start();
            }
            catch (Exception e)
            {
                Console.WriteLine(e);
                throw;
            }
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

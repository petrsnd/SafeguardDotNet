using System;
using System.Configuration;
using Serilog;

namespace Spcw.Utils
{
    public static class Config
    {
        public static string ReadRequiredSettingFromAppConfig(string key, string description)
        {
            try
            {
                var value = ConfigurationManager.AppSettings[key];
                if (!string.IsNullOrEmpty(value))
                    return value;
                Log.Error($"{key} is required in App.Config");
                throw new Exception($"Configuration Error: Unable to start with no value for {description}.");
            }
            catch (ConfigurationErrorsException ex)
            {
                Log.Error(ex, $"{key} is required in App.Config");
                throw new Exception($"Configuration Error: Unable to start without {description}.", ex);
            }
        }

        public static string ReadSettingFromAppConfigIfPresent(string key)
        {
            try
            {
                var value = ConfigurationManager.AppSettings[key];
                return !string.IsNullOrEmpty(value) ? value : null;
            }
            catch (ConfigurationErrorsException)
            {
                return null;
            }
        }

        public static SafeguardConnectionInfo GetSafeguardConnectionInformation()
        {
            var info = new SafeguardConnectionInfo
            {
                NetworkAddress =
                    ReadRequiredSettingFromAppConfig("SafeguardNetworkAddress", "Safeguard appliance network address"),
                CertificateThumbprint = ReadRequiredSettingFromAppConfig("SafeguardClientCertificateThumbprint",
                    "Safeguard client certificate thumbprint").ToUpper(),
                ApiVersion =
                    int.Parse(ReadRequiredSettingFromAppConfig("SafeguardApiVersion", "Safeguard API version")),
                IgnoreSsl = bool.Parse(ConfigurationManager.AppSettings["SafeguardIgnoreSsl"])
            };
            return info;
        }
    }
}

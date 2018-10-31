namespace Spcw.Utils
{
    public class SafeguardConnectionInfo
    {
        public string NetworkAddress { get; set; }
        public string CertificateThumbprint { get; set; }
        public int ApiVersion { get; set; }
        public bool IgnoreSsl { get; set; }
    }
}

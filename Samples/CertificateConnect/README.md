# CertificateConnect Sample

Demonstrates connecting to Safeguard using client certificate authentication
with a PKCS12 (PFX) file. This is the recommended authentication method for
automated processes and services.

## Prerequisites

Before running this sample, you must configure Safeguard:

1. **Upload the CA certificate chain** — Add the root CA and any intermediate CAs
   to Safeguard's trusted certificates (`POST TrustedCertificates`)
2. **Create a certificate user** — Create a Safeguard user with the
   `PrimaryAuthenticationProvider` set to Certificate (Id: -2) with the
   client certificate's thumbprint as the Identity

## Building

```bash
mvn clean package
```

## Running

```bash
java -jar target/certificate-connect-1.0-SNAPSHOT-jar-with-dependencies.jar <appliance> <certificate-file>
```

### Arguments

| Argument | Description |
|----------|-------------|
| appliance | IP or hostname of Safeguard appliance |
| certificate-file | Path to PKCS12/PFX client certificate file |

You will be prompted for the certificate password.

### Example

```bash
java -jar target/certificate-connect-1.0-SNAPSHOT-jar-with-dependencies.jar safeguard.example.com /path/to/client.pfx
```

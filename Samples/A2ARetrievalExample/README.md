# A2ARetrievalExample Sample

Demonstrates using Safeguard Application-to-Application (A2A) to retrieve
credentials without requiring interactive login or access request workflow
approvals. This is the primary integration method for automated systems.

## Prerequisites

Before running this sample, you must configure Safeguard:

1. **Create an Application user** — Register an application in Safeguard with
   certificate authentication
2. **Configure A2A registrations** — Set up credential retrieval registrations
   for the target asset accounts
3. **Note the API key** — Each retrieval registration is assigned an API key
   that authorizes access to a specific credential
4. **Have the PKCS12/PFX certificate** — The A2A application's client certificate

## Building

```bash
mvn clean package
```

## Running

```bash
java -jar target/a2a-retrieval-1.0-SNAPSHOT-jar-with-dependencies.jar <appliance> <certificate-file> <api-key>
```

### Arguments

| Argument | Description |
|----------|-------------|
| appliance | IP or hostname of Safeguard appliance |
| certificate-file | Path to PKCS12/PFX A2A client certificate |
| api-key | A2A API key for the credential retrieval registration |

You will be prompted for the certificate password.

### Example

```bash
java -jar target/a2a-retrieval-1.0-SNAPSHOT-jar-with-dependencies.jar \
    safeguard.example.com /path/to/a2a-cert.pfx "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
```

## How It Works

1. Creates an A2A context using the client certificate
2. Lists all retrievable accounts available to the certificate
3. Retrieves the password for the specified API key
4. Clears sensitive data from memory

In a real application, the retrieved password would be used to connect to the
target system (database, server, etc.) rather than printed to the console.

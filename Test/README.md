# Test Projects

These projects provide CLI tools for testing SafeguardDotNet against live
Safeguard appliances. The **TestFramework** orchestrates them as modular,
suite-based integration tests.

## Running Tests

See [TestFramework/README.md](TestFramework/README.md) for full documentation.

```powershell
cd TestFramework

# Run all suites
./Invoke-SafeguardTests.ps1 -Appliance sg.example.com -AdminPassword 'YourPass'

# Run specific suites
./Invoke-SafeguardTests.ps1 -Appliance sg.example.com -Suite PasswordAuth,CertificateAuth

# List available suites
./Invoke-SafeguardTests.ps1 -ListSuites
```

## Test Tools

### SafeguardDotNetTool

General-purpose Safeguard API tool. Supports password, certificate, and access token
authentication with full HTTP method control.

```powershell
# GET current user identity (password auth, read password from stdin)
dotnet run --project SafeguardDotNetTool -- -a sg.example.com -x -u Admin -p -s Core -m Get -U Me

# POST to create a user
dotnet run --project SafeguardDotNetTool -- -a sg.example.com -x -u Admin -p \
  -s Core -m Post -U Users -b '{"PrimaryAuthenticationProvider":{"Id":-1},"Name":"TestUser"}'

# GET with query parameters and CSV output
dotnet run --project SafeguardDotNetTool -- -a sg.example.com -x -u Admin -p \
  -s Core -m Get -U Users -P "filter=Name ieq 'Admin'" -C

# Full response envelope (StatusCode, Headers, Body)
dotnet run --project SafeguardDotNetTool -- -a sg.example.com -x -u Admin -p \
  -s Core -m Get -U Me -f

# Certificate authentication
dotnet run --project SafeguardDotNetTool -- -a sg.example.com -x \
  -c path/to/cert.pfx -p -s Core -m Get -U Me

# Token management: get remaining lifetime
dotnet run --project SafeguardDotNetTool -- -a sg.example.com -x -u Admin -p -T

# Token management: refresh token and show new lifetime
dotnet run --project SafeguardDotNetTool -- -a sg.example.com -x -u Admin -p -T -R

# Persistent connection with auto-refresh
dotnet run --project SafeguardDotNetTool -- -a sg.example.com -x -u Admin -p -Z \
  -s Core -m Get -U Users

# Streaming: download a backup to file
dotnet run --project SafeguardDotNetTool -- -a sg.example.com -x -u Admin -p \
  -s Appliance -m Get -U "Backups/1/Download" -F backup.sgb

# Streaming: upload a backup from file
dotnet run --project SafeguardDotNetTool -- -a sg.example.com -x -u Admin -p \
  -s Appliance -m Post -U "Backups/Upload" -F backup.sgb
```

### SafeguardDotNetA2aTool

Application-to-Application credential retrieval using certificate authentication.

```powershell
# List retrievable accounts
dotnet run --project SafeguardDotNetA2aTool -- -a sg.example.com -x \
  -c path/to/cert.pfx -p -A "your-api-key" -R

# Retrieve a password
dotnet run --project SafeguardDotNetA2aTool -- -a sg.example.com -x \
  -c path/to/cert.pfx -p -A "your-api-key"

# Retrieve an SSH private key
dotnet run --project SafeguardDotNetA2aTool -- -a sg.example.com -x \
  -c path/to/cert.pfx -p -A "your-api-key" -K

# Set a new password via A2A
dotnet run --project SafeguardDotNetA2aTool -- -a sg.example.com -x \
  -c path/to/cert.pfx -p -A "your-api-key" -N

# Using certificate from thumbprint (cert store)
dotnet run --project SafeguardDotNetA2aTool -- -a sg.example.com -x \
  -t "AB12CD34..." -A "your-api-key"
```

### SafeguardDotNetAccessRequestBrokerTool

Brokered access requests via A2A certificate authentication.

```powershell
# Create a brokered password request
dotnet run --project SafeguardDotNetAccessRequestBrokerTool -- -a sg.example.com -x \
  -c path/to/cert.pfx -p -A "broker-api-key" \
  -U "requester-username" -Y Password -S "AssetName"

# Create a brokered session request for a specific account
dotnet run --project SafeguardDotNetAccessRequestBrokerTool -- -a sg.example.com -x \
  -c path/to/cert.pfx -p -A "broker-api-key" \
  -U "requester-username" -Y RemoteDesktop -S "AssetName" -C "root"
```

### SafeguardDotNetEventTool

SignalR event listener for Safeguard API events and A2A notifications.

```powershell
# Listen for UserCreated events (standard listener)
dotnet run --project SafeguardDotNetEventTool -- -a sg.example.com -x \
  -u Admin -p -E UserCreated

# Persistent listener (auto-reconnect on disconnection)
dotnet run --project SafeguardDotNetEventTool -- -a sg.example.com -x \
  -u Admin -p -E UserCreated -P

# Persistent listener with state change callbacks
dotnet run --project SafeguardDotNetEventTool -- -a sg.example.com -x \
  -u Admin -p -E UserCreated -P -S

# A2A event listener (certificate auth)
dotnet run --project SafeguardDotNetEventTool -- -a sg.example.com -x \
  -c path/to/cert.pfx -p -A "api-key-1,api-key-2"
```

### SafeguardDotNetExceptionTest

Validates SafeguardDotNet exception handling for connection and API errors.

```powershell
# Run exception tests with password auth
dotnet run --project SafeguardDotNetExceptionTest -- -a sg.example.com -x -u Admin -p

# Run exception tests anonymously
dotnet run --project SafeguardDotNetExceptionTest -- -a sg.example.com -x -A
```

### SafeguardSessionsDotNetTool

Calls the Safeguard for Privileged Sessions (SPS) API.

```powershell
# GET SPS firmware info
dotnet run --project SafeguardSessionsDotNetTool -- \
  -a sps.example.com -u admin -p password -m Get -U "firmware/slots"

# GET SPS configuration
dotnet run --project SafeguardSessionsDotNetTool -- \
  -a sps.example.com -k -u admin -p password -m Get -U "configuration"
```

### SafeguardDotNetGuiTester

Interactive GUI login component tester. This is a .NET Framework 4.8.1 WinForms
application — build with `msbuild SafeguardDotNet.Framework.sln` and run the
resulting executable.

## Test Data

The `TestData/CERTS/` directory contains test certificates (Root CA, Intermediate CA,
User Certificate) used by certificate authentication and A2A test suites.

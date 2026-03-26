# AGENTS.md -- SafeguardDotNet

.NET SDK for the One Identity Safeguard Web API. Published as NuGet packages on
[NuGet.org](https://www.nuget.org/packages/OneIdentity.SafeguardDotNet).

Targets `netstandard2.0`. Root namespace: `OneIdentity.SafeguardDotNet`. Dependencies:
Newtonsoft.Json, Serilog, Microsoft.AspNetCore.SignalR.Client.

## Project structure

```
SafeguardDotNet/
|-- SafeguardDotNet/                           # Core SDK library (netstandard2.0)
|   |-- Safeguard.cs                           # Entry point: Connect(), A2A, Event, AgentBasedLoginUtils
|   |-- ISafeguardConnection.cs                # Primary connection interface
|   |-- SafeguardConnection.cs                 # Base connection implementation
|   |-- PersistentSafeguardConnection.cs       # Auto-refreshing token decorator
|   |-- SafeguardDotNetException.cs            # All SDK errors thrown as this type
|   |-- ExtensionMethods.cs                    # SecureString <-> string conversions
|   |-- Authentication/                        # IAuthenticationMechanism strategy pattern
|   |   |-- IAuthenticationMechanism.cs        # Auth interface contract
|   |   |-- AuthenticatorBase.cs               # Shared auth logic
|   |   |-- PasswordAuthenticator.cs           # Username/password via ROG
|   |   |-- CertificateAuthenticator.cs        # Client certificate (thumbprint, file, memory)
|   |   |-- AccessTokenAuthenticator.cs        # Pre-existing access token
|   |   |-- AnonymousAuthenticator.cs          # Unauthenticated connection
|   |   `-- ManagementServiceAuthenticator.cs  # Management service (DR, support)
|   |-- Event/                                 # SignalR event listeners
|   |   |-- ISafeguardEventListener.cs         # Event listener interface
|   |   |-- SafeguardEventListener.cs          # Standard listener (no reconnect)
|   |   |-- PersistentSafeguardEventListenerBase.cs  # Auto-reconnect base class
|   |   |-- PersistentSafeguardEventListener.cs      # Production-grade listener
|   |   |-- PersistentSafeguardA2AEventListener.cs   # A2A-specific persistent listener
|   |   `-- EventHandlerRegistry.cs            # Event handler registration
|   |-- A2A/                                   # Application-to-Application (certificate-only)
|   `-- Sps/                                   # Safeguard for Privileged Sessions integration
|
|-- SafeguardDotNet.PkceNoninteractiveLogin/   # PKCE login without a browser (MFA support)
|-- SafeguardDotNet.BrowserLogin/              # PKCE login via system browser
|-- SafeguardDotNet.GuiLogin/                  # WinForms embedded browser login (.NET Framework)
|-- SafeguardDotNet.LoginCommon/               # Shared login utilities
|
|-- Test/                                      # CLI test tools and integration test framework
|   |-- SafeguardDotNetTool/                   # General-purpose SDK test CLI
|   |-- SafeguardDotNetPkceNoninteractiveLoginTester/  # PKCE login tester
|   |-- SafeguardDotNetBrowserLoginTester/     # Browser login tester
|   |-- SafeguardDotNetA2aTool/                # A2A test CLI
|   |-- SafeguardDotNetAccessRequestBrokerTool/  # Access request broker tester
|   |-- SafeguardDotNetEventTool/              # Event listener tester
|   |-- SafeguardDotNetExceptionTest/          # Exception handling tester
|   |-- SafeguardSessionsDotNetTool/           # SPS integration tester
|   |-- SafeguardDotNetGuiTester/              # GUI login tester (.NET Framework)
|   `-- TestFramework/                         # PowerShell integration test framework
|       |-- Invoke-SafeguardTests.ps1          # Test runner entry point
|       |-- SafeguardTestFramework.psm1        # Framework module (assertions, helpers)
|       `-- Suites/Suite-*.ps1                 # Test suite files (auto-discovered)
|
|-- Samples/                                   # Example projects
|   |-- SampleA2aService/                      # A2A credential retrieval sample
|   `-- ServiceNowTicketValidator/             # Ticket system integration sample
|
|-- Directory.Build.props                      # Shared MSBuild props (analyzers, code style)
|-- stylecop.json                              # StyleCop configuration
|-- build.yml                                  # Azure Pipelines CI/CD definition
|-- versionnumber.ps1                          # CI version replacement script
|-- pipeline-templates/                        # Azure Pipelines template files
`-- data/                                      # Data files (certificates, etc.)
```

## Setup and build commands

There are three solution files serving different purposes:

| Solution | Contents | Build tool |
|---|---|---|
| `SafeguardDotNet.Core.sln` | SDK + login modules + test tools + samples (modern .NET) | `dotnet build` |
| `SafeguardDotNet.Framework.sln` | GuiLogin + GuiTester + ServiceNowTicketValidator (.NET Framework 4.8.1) | `msbuild` |
| `SafeguardDotNet.sln` | NuGet restore only — references all projects for package restore, not for build |

```powershell
# Day-to-day local build (most common -- use this)
dotnet build SafeguardDotNet.Core.sln /p:SignFiles=false

# Build just the SDK project
dotnet build SafeguardDotNet\SafeguardDotNet.csproj

# Build a specific test tool
dotnet build Test\SafeguardDotNetPkceNoninteractiveLoginTester\SafeguardDotNetPkceNoninteractiveLoginTester.csproj

# Full CI-equivalent build (requires .NET Framework 4.8.1 Developer Pack)
nuget restore SafeguardDotNet.sln
dotnet build SafeguardDotNet.Core.sln --configuration Release --no-restore /p:SignFiles=false
msbuild SafeguardDotNet.Framework.sln /p:Configuration=Release /p:SignFiles=false
```

**Always pass `/p:SignFiles=false` for local builds.** The CI pipeline uses Azure Key Vault
for code signing — local builds without this flag will fail on signing steps.

The build must complete with **0 errors, 0 warnings**. The project enforces strict code
analysis via `Directory.Build.props`:
- `EnforceCodeStyleInBuild = true`
- StyleCop.Analyzers (v1.2.0-beta.556)
- SonarAnalyzer.CSharp (v10.20.0)

If you introduce a warning, fix it before considering the change complete.

## Linting and code analysis

Linting is integrated into the build via Roslyn analyzers. There is no separate lint command.
Running `dotnet build` with the enforced analyzers catches all issues at compile time.

Key rules enforced (learn these to avoid common build failures):

| Rule | What it means |
|------|---------------|
| SA1124 | No `#region` directives allowed |
| SA1117 | Parameters must each be on their own line when split across lines |
| SA1306/IDE1006 | Private static fields use `s_` prefix, start lowercase |
| SA1501 | No single-line statement blocks (always use braces on separate lines) |
| S2737 | No empty catch clauses (must handle or rethrow meaningfully) |
| IDE0063 | Prefer simplified `using` declarations |
| IDE0078 | Prefer pattern matching |
| IDE0054 | Prefer compound assignment |
| CA5350 | HMACSHA1 flagged as weak crypto (use `#pragma warning disable` if needed) |

## Testing against a live appliance

This SDK interacts with a live Safeguard appliance API. **There are no mock/unit tests.**
The `Test/` directory contains CLI tools that require a live appliance and a PowerShell
integration test framework. Running tests against a live appliance is the only way to
validate changes.

### Asking the user for appliance access

**If you are making non-trivial code changes, ask the user whether they have access to a
live Safeguard appliance for testing.** If they do, ask for:

1. **Appliance address** (IP or hostname of a Safeguard for Privileged Passwords appliance)
2. **Admin username** (typically `Admin` — the built-in admin account)
3. **Admin password** (for the admin account above)
4. *(Optional)* **TOTP seed** (Base32-encoded secret for MFA-enabled user, if testing MFA)
5. *(Optional)* **SPS appliance address** (for Safeguard for Privileged Sessions tests)
6. *(Optional)* **SPS credentials** (username and password)

This is not required for documentation or minor fixes, but it is **strongly encouraged**
for any change that touches authentication, API calls, connection logic, or event handling.

### Connecting to the appliance (PKCE vs Resource Owner Grant)

**Resource Owner Grant (ROG) is disabled by default** on Safeguard appliances. The SDK's
`PasswordAuthenticator` uses ROG under the hood, which will fail with a 400 error when ROG
is disabled.

**Always use PKCE as the default connection method** for testing:

```csharp
// Using the PKCE non-interactive login module
var connection = PkceNoninteractiveLogin.Connect(
    appliance, "local", "Admin", password.ToSecureString(),
    apiVersion: 4, ignoreSsl: true);
```

Or via the CLI test tool:
```powershell
dotnet run --project Test\SafeguardDotNetPkceNoninteractiveLoginTester -- `
    -a <appliance> -i local -u Admin -x
# (reads password from stdin)
```

If you attempt a `Safeguard.Connect()` with username/password and receive a 400 error like
`"OAuth2 resource owner password credentials grant type is not allowed"`, switch to PKCE.
**Do not try to enable ROG on the appliance** — use PKCE as the standard approach.

The PowerShell test runner (`Invoke-SafeguardTests.ps1`) uses PKCE for its preflight
connection check.

### Running the PowerShell test suite

```powershell
# Build first (always build before testing)
dotnet build SafeguardDotNet.Core.sln /p:SignFiles=false

# Run all suites
pwsh -File Test\TestFramework\Invoke-SafeguardTests.ps1 `
    -Appliance <address> -AdminUserName Admin -AdminPassword <password>

# Run a specific suite
pwsh -File Test\TestFramework\Invoke-SafeguardTests.ps1 `
    -Appliance <address> -AdminUserName Admin -AdminPassword <password> `
    -Suite PkceAuthentication

# Run MFA tests (requires TOTP-enabled user with the same credentials)
pwsh -File Test\TestFramework\Invoke-SafeguardTests.ps1 `
    -Appliance <address> -AdminUserName <mfa-user> -AdminPassword <password> `
    -Suite PkceAuthentication -TotpSeed <base32-totp-secret>

# List available suites
pwsh -File Test\TestFramework\Invoke-SafeguardTests.ps1 -ListSuites
```

**Important:** The test runner requires **PowerShell 7** (`pwsh`). It:
- Validates the appliance is reachable (preflight HTTPS check)
- Authenticates using PKCE (not ROG) to verify credentials
- Discovers and runs suite files from `Test/TestFramework/Suites/`
- Reports pass/fail/skip with structured output

### Running individual CLI test tools

Each test tool in `Test/` is a standalone CLI application:

```powershell
# PKCE login tester (basic)
dotnet run --project Test\SafeguardDotNetPkceNoninteractiveLoginTester -- `
    -a <appliance> -i local -u Admin -x
# Enter password when prompted via stdin

# PKCE login tester with MFA (TOTP)
dotnet run --project Test\SafeguardDotNetPkceNoninteractiveLoginTester -- `
    -a <appliance> -i local -u <mfa-user> -s <totp-code> -x
# Enter password when prompted via stdin

# General SDK test tool
dotnet run --project Test\SafeguardDotNetTool -- `
    -a <appliance> -i local -u Admin -x -m Get -U "v4/Me"
# Enter password when prompted via stdin
```

### Module-to-suite mapping

When you change a specific SDK module, run the relevant suite(s) rather than the full set:

| SDK module / project | Relevant test suite(s) |
|---|---|
| `SafeguardDotNet.PkceNoninteractiveLogin/` | PkceAuthentication |
| `SafeguardDotNet/Safeguard.cs` | PasswordAuth, CertificateAuth, AccessTokenAuth, AnonymousAccess |
| `SafeguardDotNet/SafeguardConnection.cs` | ApiInvocation, PersistentConnection, TokenManagement |
| `SafeguardDotNet/Authentication/` | PasswordAuth, CertificateAuth, AccessTokenAuth |
| `SafeguardDotNet/Event/` | EventListeners |
| `SafeguardDotNet/A2A/` | A2ACredentialRetrieval, A2AAccessRequestBroker |
| `SafeguardDotNet/Sps/` | SpsIntegration (requires SPS appliance) |
| `SafeguardDotNet/SafeguardDotNetException.cs` | ExceptionHandling |
| `SafeguardDotNet/*Streaming*` | Streaming |

### Fixing test failures

When a test fails, **investigate and fix the source code first** — do not change the test
to make it pass without asking the user. The test suite exists to catch regressions.

Only modify a test if:
- The test itself has a genuine bug (wrong assertion logic, stale assumptions)
- The user explicitly approves changing the test
- A new feature intentionally changes behavior and the test needs updating

Always ask the user before weakening or removing an assertion.

## Exploring the Safeguard API

The appliance exposes Swagger UI for each service at:
- `https://<appliance>/service/core/swagger` — Core service (assets, users, policies, requests)
- `https://<appliance>/service/appliance/swagger` — Appliance service (networking, diagnostics)
- `https://<appliance>/service/notification/swagger` — Notification service (events)
- `https://<appliance>/service/event/swagger` — Event service (SignalR streaming)

Use Swagger to discover endpoints, required fields, query parameters, and response schemas.
The default API version is **v4** (`Safeguard.DefaultApiVersion = 4`). Pass `apiVersion: 3`
to any connection method for legacy v3. Both coexist in Safeguard 7.x+.

## Architecture

### Entry point (`Safeguard.cs`)

The static `Safeguard` class is the SDK's public entry point. It provides:
- **18 `Connect()` overloads** — anonymous, access token, password, certificate (thumbprint/file/memory)
- **`Safeguard.Event.GetPersistentEventListener()`** — persistent SignalR event listeners
- **`Safeguard.A2A.GetContext()`** — certificate-only A2A context
- **`Safeguard.AgentBasedLoginUtils`** — PKCE helpers (code verifier, code challenge, CSRF tokens)
- **`Safeguard.Persist()`** — wraps a connection in `PersistentSafeguardConnection` for auto-refresh

### Authentication strategy pattern (`Authentication/`)

All authenticators implement `IAuthenticationMechanism`. When adding a new authentication
method:
1. Implement `IAuthenticationMechanism` in `SafeguardDotNet/Authentication/`
2. Add `Safeguard.Connect()` overload(s) in `Safeguard.cs`
3. Use the private `GetConnection()` helper to ensure token refresh on initial creation

### Connection classes

- **`SafeguardConnection`** — Base `ISafeguardConnection` implementation. Makes HTTP calls via
  `InvokeMethod()` / `InvokeMethodFull()`. Implements `ICloneable`.
- **`PersistentSafeguardConnection`** — Decorator that checks `GetAccessTokenLifetimeRemaining() <= 0`
  before each call and auto-refreshes tokens.
- **`SafeguardManagementServiceConnection`** — For management service (disaster recovery, support).

### PKCE non-interactive login (`SafeguardDotNet.PkceNoninteractiveLogin/`)

Simulates the browser-based PKCE OAuth2 flow by directly interacting with rSTS endpoints.
Supports primary (password) and secondary (MFA/TOTP) authentication.

Two public `Connect()` overloads:
```csharp
// Without MFA
PkceNoninteractiveLogin.Connect(appliance, provider, username, password, apiVersion, ignoreSsl)

// With MFA (secondaryPassword is the TOTP code or RADIUS response)
PkceNoninteractiveLogin.Connect(appliance, provider, username, password, secondaryPassword, apiVersion, ignoreSsl)
```

### rSTS login flow (critical implementation detail)

The rSTS login controller at `/RSTS/UserLogin/LoginController` uses a `loginRequestStep`
query parameter. The non-interactive PKCE module drives this flow programmatically:

| Step | Constant | Purpose | Key response |
|------|----------|---------|-------------|
| 1 | `StepInit` | Provider initialization | Provider list, CSRF token |
| 3 | `StepPrimaryAuth` | Primary auth (password) | `SecondaryProviderID` if MFA required |
| 7 | `StepSecondaryInit` | Init secondary provider | `Message` (prompt), `State` (MFA context) |
| 5 | `StepSecondaryAuth` | Submit MFA code | Empty on success, 203 with error JSON on failure |
| 6 | `StepGenerateClaims` | Generate claims | `RelyingPartyUrl` with authorization code |

**HTTP status codes from rSTS:**
- **200** — Success
- **203** — rSTS challenge/error (NOT a standard HTTP error; body is JSON with `Message`/`State`)
- **400** — Hard error (plain text body, e.g., "Invalid password." or "Access denied.")

**Appliance error message configuration:** Detailed error messages (e.g., "Invalid password.",
"User is unknown.") can be enabled or disabled on the appliance. When disabled, all auth
failures return the generic "Access denied." message. Test assertions must handle both cases.

**rSTS rate limiting:** The rSTS login controller has aggressive per-user rate limiting.
Multiple authentication requests in quick succession trigger `"There have been too many
authentication requests for this user"` with a cooldown window of several minutes. This
affects PKCE flows but NOT the Resource Owner Grant token endpoint. When writing tests,
minimize the number of authentication attempts per user and space them out.

### Event listeners (`Event/`)

- **`SafeguardEventListener`** — Standard SignalR listener. Does NOT survive 30+ second outages.
- **`PersistentSafeguardEventListenerBase`** — Base class with exponential backoff reconnect.
- **`PersistentSafeguardEventListener`** — Production-grade persistent listener.
- **`PersistentSafeguardA2AEventListener`** — Persistent A2A-specific variant.
- Use `GetPersistentEventListener()` for production deployments.

### A2A (`A2A/`)

Certificate-only authentication for automated credential retrieval. Key types:
`ISafeguardA2AContext`, `A2ARetrievableAccount`, `BrokeredAccessRequest`, `ApiKeySecret`.

### SPS integration (`Sps/`)

Integration with Safeguard for Privileged Sessions. `ISafeguardSessionsConnection` /
`SafeguardSessionsConnection`, joined via `ISafeguardConnection.JoinSps()`.

## Code conventions

### SecureString for credentials

All passwords and tokens must be stored as `SecureString`. Convert with extension methods
in `ExtensionMethods.cs`:

```csharp
string password = "secret";
SecureString secure = password.ToSecureString();
string insecure = secure.ToInsecureString();
```

Types holding `SecureString` fields (e.g., `ApiKeySecret`, `A2ARetrievableAccount`)
implement `IDisposable` to clear sensitive data.

### Dispose pattern

Connection classes track a `_disposed` field. All public instance methods must check it and
throw `ObjectDisposedException` if the connection has been disposed:

```csharp
if (_disposed)
    throw new ObjectDisposedException("SafeguardConnection");
```

Follow this pattern in any new connection or context class.

### Error handling

All SDK errors throw `SafeguardDotNetException`, which carries:
- `HttpStatusCode` — the HTTP status code from the API
- `ErrorCode` — Safeguard-specific error code (parsed from JSON response)
- `ErrorMessage` — Human-readable error message (parsed from JSON response)
- `Response` — Raw response body string

The constructor automatically parses JSON error responses. When throwing from new code,
include the HTTP status code and response body when available.

### SSL/TLS

- TLS 1.2 is enforced on all `HttpClientHandler` instances (`SslProtocols = SslProtocols.Tls12`)
- `ignoreSsl` parameter bypasses certificate validation (development only)
- `validationCallback` parameter (`RemoteCertificateValidationCallback`) for custom validation
- Both must be applied consistently across `HttpClient` and SignalR connections
- **Never recommend `ignoreSsl` for production** without explicit warning

### Naming conventions

- Private static fields: `s_` prefix, camelCase (e.g., `s_defaultTimeout`)
- Private instance fields: `_` prefix, camelCase (e.g., `_disposed`)
- Public properties: PascalCase
- Constants: PascalCase (e.g., `DefaultApiVersion`)
- Step constants in PKCE: `StepInit`, `StepPrimaryAuth`, etc.

### XML documentation

`GenerateDocumentationFile` is enabled in `Directory.Build.props`. All public types and
members should have XML doc comments. The StyleCop `xmlHeader` rule is disabled — do not
add XML file headers.

### Versioning

Version markers `9999.9999.9999` (packages) and `9999.9999.9999.9999` (assemblies) appear
in `.csproj` and `.nuspec` files. `versionnumber.ps1` replaces them at CI build time.
**Do not change these markers manually.**

### NuGet packages produced

Four packages are published on every release:
1. `OneIdentity.SafeguardDotNet` — Core SDK
2. `OneIdentity.SafeguardDotNet.BrowserLogin` — Browser-based PKCE login
3. `OneIdentity.SafeguardDotNet.PkceNoninteractiveLogin` — Non-interactive PKCE login
4. `OneIdentity.SafeguardDotNet.GuiLogin` — WinForms embedded browser login

Each package includes a `.snupkg` symbols package.

## Writing a new test suite

### Suite file structure

Create `Test/TestFramework/Suites/Suite-YourFeature.ps1` returning a hashtable:

```powershell
@{
    Name        = "Your Feature"
    Description = "Tests for your feature"
    Tags        = @("yourfeature")

    Setup = {
        param($Context)
        # Setup code — prepare test data, store in $Context.SuiteData
        # Keep setup minimal; the test runner handles authentication
    }

    Execute = {
        param($Context)

        # Success test
        Test-SgDnAssert "Can do the thing" {
            $result = Invoke-SgDnSafeguardTool -ProjectDir $Context.SomeToolDir `
                -Arguments "-a $($Context.Appliance) -i local -u $($Context.AdminUserName) -x" `
                -StdinLine $Context.AdminPassword
            $result -match "expected output"
        }

        # Error test
        Test-SgDnAssertThrows "Rejects bad input" `
            -Match "expected error message" `
            -ScriptBlock {
                Invoke-SgDnSafeguardTool -ProjectDir $Context.SomeToolDir `
                    -Arguments "-a $($Context.Appliance) -i local -u BadUser -x" `
                    -StdinLine "wrong"
            }
    }

    Cleanup = {
        param($Context)
        # Cleanup code — remove test objects
    }
}
```

### Available context properties

The `$Context` object provides:

| Property | Description |
|---|---|
| `$Context.Appliance` | Appliance network address |
| `$Context.AdminUserName` | Admin username (from CLI) |
| `$Context.AdminPassword` | Admin password (from CLI) |
| `$Context.TotpSeed` | Base32 TOTP seed (from CLI `-TotpSeed`, or `$null`) |
| `$Context.PkceToolDir` | Path to `Test/SafeguardDotNetPkceNoninteractiveLoginTester` |
| `$Context.SuiteData` | Hashtable for per-suite state (shared between Setup/Execute/Cleanup) |
| `$Context.TestPrefix` | Name prefix for test objects (default: "SgDnTest") |

### Available assertion functions

| Function | Purpose |
|---|---|
| `Test-SgDnAssert "name" { <bool-expr> }` | Assert a boolean expression is `$true` |
| `Test-SgDnAssertEqual "name" -Expected $a -Actual $b` | Assert equality |
| `Test-SgDnAssertNotNull "name" -Value $x` | Assert value is not `$null` |
| `Test-SgDnAssertContains "name" -Collection $arr -Item $x` | Assert collection contains item |
| `Test-SgDnAssertThrows "name" -Match "pattern" -ScriptBlock { ... }` | Assert code throws with matching message |
| `Test-SgDnSkip "reason"` | Skip remaining tests in suite |

### Running test tools from suites

Use `Invoke-SgDnSafeguardTool` to run CLI test tools and capture their output:

```powershell
$result = Invoke-SgDnSafeguardTool `
    -ProjectDir $Context.PkceToolDir `
    -Arguments "-a $($Context.Appliance) -i local -u $($Context.AdminUserName) -x" `
    -StdinLine $Context.AdminPassword `
    -ParseJson $true    # Parse JSON output (default: $true)
```

The function runs `dotnet run --project <dir> -- <arguments>`, pipes `StdinLine` to stdin,
and captures stdout. Set `-ParseJson $false` for non-JSON output.

### Generating TOTP codes in tests

Do not generate TOTP codes in C# — use Python from within the PowerShell test:

```powershell
$totpCode = python -c @"
import hmac, hashlib, struct, time, base64
key = base64.b32decode('$($Context.TotpSeed)')
t = struct.pack('>Q', int(time.time()) // 30)
h = hmac.new(key, t, hashlib.sha1).digest()
o = h[-1] & 0xF
code = (struct.unpack('>I', h[o:o+4])[0] & 0x7FFFFFFF) % 1000000
print(f'{code:06d}')
"@
```

This avoids adding crypto dependencies to the SDK and keeps TOTP generation in the test
layer where it belongs.

### Writing strong test assertions

Tests must validate that operations **actually worked** — not just that they did not throw.
The goal is to catch regressions, confirm the API contract, and prove that data round-trips
correctly.

**Principles:**

1. **Assert specific values, not just existence.** Do not write `$null -ne $result` as the
   only check. Verify concrete field values in the response.

2. **Test error paths.** When an operation should fail, verify it throws with an appropriate
   error message. Use `Test-SgDnAssertThrows` with `-Match` to confirm the error is specific.

3. **Handle appliance configuration differences.** Some error messages change based on
   appliance settings (e.g., detailed error messages can be disabled, making all auth
   failures return "Access denied."). Use manual try/catch with `-match` against multiple
   acceptable patterns when needed:

   ```powershell
   Test-SgDnAssert "Wrong password gives appropriate error" {
       $threw = $false
       try {
           Invoke-SgDnSafeguardTool -ProjectDir $Context.PkceToolDir `
               -Arguments "..." -StdinLine "wrongpassword"
       }
       catch {
           $threw = ($_.Exception.Message -match "Invalid password") -or
                    ($_.Exception.Message -match "Access denied")
       }
       $threw
   }
   ```

4. **Be mindful of rSTS rate limiting.** Multiple failed authentication attempts against
   the same user trigger rate limiting. In error-path tests, keep failure count low and
   only run them in standard (non-MFA) mode.

5. **Test both modes when applicable.** The PKCE test suite supports two modes:
   - **Standard mode** (no `TotpSeed`): Runs login success + error tests
   - **MFA mode** (`TotpSeed` provided): Runs only the TOTP success test

## CI/CD pipeline

The project uses Azure Pipelines (not GitHub Actions). The pipeline definition is in
`build.yml` with templates in `pipeline-templates/`.

Two jobs:
- **PRValidation** — runs on pull requests (no code signing)
- **BuildAndPublish** — runs on merge to master/release branches (code signing + NuGet publish)

CI uses Azure Key Vault secrets and eSignerCKA for code signing. Never add code that
assumes those secrets exist locally.

## Security considerations

- Never commit secrets, tokens, or credentials to source
- `SecureString` variables contain sensitive data — do not log or serialize them
- Test credentials should only appear in test runner parameters, never hardcoded in suites
- The `ignoreSsl` / `-x` switch disables SSL verification for development — always warn
  about production use
- The TOTP seed is passed via CLI parameter and should never be committed to source

## Keeping this file current

After completing a series of tasks, review what you learned and suggest updates to this
file. Things to look for:

- **New API quirks or pitfalls** that caused debugging time (e.g., rSTS behavior,
  serialization issues, rate limiting)
- **New test suites** — update the module-to-suite mapping table
- **New patterns** that future work should follow (e.g., new authentication methods,
  connection types, event listener patterns)
- **Stale information** — suite count, assertion functions, CLI options may drift as
  code evolves
- **Corrections** to anything that turned out to be wrong or misleading

# SafeguardDotNet Test Framework

A PowerShell 7.x test framework for running SafeguardDotNet integration tests against
live Safeguard appliances.

## Prerequisites

- **PowerShell 7.x** or later (`pwsh`)
- **.NET SDK** (for building and running test tool projects)
- A live **Safeguard appliance** accessible over the network
- Optional: A **Safeguard for Privileged Sessions** appliance

## Quick Start

```powershell
# Run all test suites
./Invoke-SafeguardTests.ps1 -Appliance sg.example.com

# Run specific suites
./Invoke-SafeguardTests.ps1 -Appliance sg.example.com -Suite PasswordAuth,CertificateAuth

# List available suites
./Invoke-SafeguardTests.ps1 -ListSuites

# Export results to JSON for CI
./Invoke-SafeguardTests.ps1 -Appliance sg.example.com -ReportPath results.json

# Skip build step (when already built)
./Invoke-SafeguardTests.ps1 -Appliance sg.example.com -SkipBuild

# Exclude specific suites
./Invoke-SafeguardTests.ps1 -Appliance sg.example.com -ExcludeSuite EventListeners,Streaming
```

## Parameters

| Parameter | Required | Default | Description |
|---|---|---|---|
| `-Appliance` | Yes (for run) | — | Safeguard appliance address |
| `-AdminUserName` | No | `admin` | Bootstrap admin username |
| `-AdminPassword` | No | `Admin123` | Bootstrap admin password |
| `-SpsAppliance` | No | — | SPS appliance address |
| `-SpsUser` | No | `admin` | SPS admin username |
| `-SpsPassword` | No | — | SPS admin password |
| `-Suite` | No | (all) | Suite name filter (supports wildcards) |
| `-ExcludeSuite` | No | (none) | Suite names to skip (supports wildcards) |
| `-ListSuites` | No | — | List available suites without running |
| `-ReportPath` | No | — | Export JSON report to file |
| `-SkipBuild` | No | — | Skip building test projects |
| `-TestPrefix` | No | `SgDnTest` | Prefix for test objects on the appliance |

## Architecture

### Directory Structure

```
TestFramework/
├── Invoke-SafeguardTests.ps1       # Test runner entry point
├── SafeguardTestFramework.psm1     # Core framework module
├── README.md                       # This file
└── Suites/                         # Individual test suite files
    ├── Suite-AnonymousAccess.ps1
    ├── Suite-PasswordAuth.ps1
    └── ...
```

### Suite Lifecycle

Every suite follows a three-phase lifecycle: **Setup → Execute → Cleanup**.

```
Setup    → Create test objects on the appliance (users, certs, assets, etc.)
Execute  → Run test assertions against the SDK
Cleanup  → Remove all test objects (always runs, even on failure)
```

- **Setup** failures skip the Execute phase but Cleanup always runs.
- **Execute** uses continue-on-failure — each assertion is independent.
- **Cleanup** actions are idempotent — they attempt to remove objects that may or
  may not exist, and silently ignore failures.

### Writing a Suite

Create a file named `Suite-YourSuiteName.ps1` in the `Suites/` directory. The file
must return a hashtable with this structure:

```powershell
@{
    Name        = "Your Suite Name"
    Description = "Brief description of what this suite tests"
    Tags        = @("auth", "core")

    Setup = {
        param($Context)

        # Create test objects and register cleanup
        $user = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "Users" -Body @{
                PrimaryAuthenticationProvider = @{ Id = -1 }
                Name = "$($Context.TestPrefix)_MyUser"
            }
        $Context.SuiteData["UserId"] = $user.Id

        # Register cleanup — runs even if later tests fail
        Register-SgDnTestCleanup -Description "Delete test user" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx -RelativeUrl "Users/$($Ctx.SuiteData['UserId'])"
        }
    }

    Execute = {
        param($Context)

        Test-SgDnAssert "Can authenticate with test user" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core `
                -Method Get -RelativeUrl "Me" `
                -Username "$($Context.TestPrefix)_MyUser" `
                -Password "TestPass123!"
            $result.Name -eq "$($Context.TestPrefix)_MyUser"
        }

        Test-SgDnAssertNotNull "User has valid ID" $Context.SuiteData["UserId"]

        Test-SgDnAssertEqual "User name matches" `
            "$($Context.TestPrefix)_MyUser" `
            $Context.SuiteData["UserName"]

        Test-SgDnAssertThrows "Invalid endpoint throws" {
            Invoke-SgDnSafeguardApi -Context $Context -Service Core `
                -Method Get -RelativeUrl "NonExistent"
        }

        # Skip tests with a reason
        if (-not (Test-SgDnIsElevated)) {
            Test-SgDnSkip "Computer cert store auth" "Requires elevation"
        }
    }

    Cleanup = {
        param($Context)
        # Additional manual cleanup beyond registered actions (optional)
    }
}
```

### Available Assertion Functions

| Function | Description |
|---|---|
| `Test-SgDnAssert "name" { ... }` | Pass if scriptblock returns truthy / doesn't throw |
| `Test-SgDnAssertEqual "name" $expected $actual` | Pass if values are equal |
| `Test-SgDnAssertNotNull "name" $value` | Pass if value is not null/empty |
| `Test-SgDnAssertContains "name" $haystack $needle` | Pass if contains substring/element |
| `Test-SgDnAssertThrows "name" { ... }` | Pass if scriptblock throws |
| `Test-SgDnSkip "name" "reason"` | Record a skipped test |

### Available Tool Invocation Functions

| Function | Description |
|---|---|
| `Invoke-SgDnSafeguardApi` | Call Safeguard API via SafeguardDotNetTool |
| `Invoke-SgDnSafeguardA2aTool` | Call A2A operations via SafeguardDotNetA2aTool |
| `Invoke-SgDnSafeguardSessionsTool` | Call SPS API via SafeguardSessionsDotNetTool |
| `Invoke-SgDnSafeguardTool` | Low-level: run any dotnet test tool project |

### Available Helper Functions

| Function | Description |
|---|---|
| `Register-SgDnTestCleanup` | Register a LIFO cleanup action |
| `Remove-SgDnSafeguardTestObject` | Idempotent DELETE (ignores 404) |
| `Build-SgDnTestProjects` | Build all test tool projects |
| `Test-SgDnSpsConfigured` | Check if SPS parameters are set |
| `Test-SgDnIsElevated` | Check if running as admin |
| `Get-SgDnTestContext` | Get the current test context |

## CI Integration

The runner exits with code `1` if any tests fail, `0` if all pass. Use `-ReportPath`
to export a JSON report:

```json
{
  "Appliance": "sg.example.com",
  "StartTime": "2026-03-16T10:00:00Z",
  "EndTime": "2026-03-16T10:04:23Z",
  "Suites": [
    {
      "Name": "Password Authentication",
      "DurationMs": 4500,
      "Tests": [
        { "Name": "Can login", "Status": "Pass", "DurationMs": 1200 },
        { "Name": "Returns identity", "Status": "Pass", "DurationMs": 800 }
      ]
    }
  ],
  "Summary": { "TotalPass": 33, "TotalFail": 2, "TotalSkip": 1 }
}
```

## Differences from Legacy Script

The legacy `Test/Invoke-SafeguardDotNetTests.ps1` is preserved for backward compatibility
but is deprecated. Key improvements in this framework:

| Legacy | New Framework |
|---|---|
| Single monolithic script | Modular suite files |
| `$ErrorActionPreference = "Stop"` | Continue-on-failure with reporting |
| No cleanup | Idempotent LIFO cleanup always runs |
| `Invoke-Expression` for tool calls | `System.Diagnostics.Process` with proper I/O |
| Regex error detection ("Error"/"Exception") | Exit code checking |
| No reporting | Structured console + JSON reports |
| Can't run subsets | `-Suite` / `-ExcludeSuite` filtering |

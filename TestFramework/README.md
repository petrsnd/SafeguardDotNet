# SafeguardJava Test Framework

Integration test framework for the SafeguardJava SDK. Tests run against a live
Safeguard appliance using the SafeguardJavaTool CLI.

## Prerequisites

- PowerShell 7.0+
- Java 8+ (JDK)
- Maven 3.6+
- A Safeguard appliance with admin credentials

## Quick Start

```powershell
# Run all test suites
./TestFramework/Invoke-SafeguardTests.ps1 -Appliance 192.168.1.100 -AdminPassword "YourPassword"

# Run specific suites
./TestFramework/Invoke-SafeguardTests.ps1 -Appliance sg.example.com -Suite PasswordAuth,AnonymousAccess

# List available suites
./TestFramework/Invoke-SafeguardTests.ps1 -ListSuites

# Skip build (if already built)
./TestFramework/Invoke-SafeguardTests.ps1 -Appliance sg.example.com -AdminPassword "pw" -SkipBuild

# Export JSON report
./TestFramework/Invoke-SafeguardTests.ps1 -Appliance sg.example.com -AdminPassword "pw" -ReportPath results.json

# Specify Maven path
./TestFramework/Invoke-SafeguardTests.ps1 -Appliance sg.example.com -AdminPassword "pw" -MavenCmd "C:\tools\maven\bin\mvn.cmd"
```

## Architecture

```
TestFramework/
  Invoke-SafeguardTests.ps1      # Entry point / test runner
  SafeguardTestFramework.psm1    # Core framework module
  README.md                      # This file
  Suites/
    Suite-AnonymousAccess.ps1    # Anonymous endpoint tests
    Suite-PasswordAuth.ps1       # Password authentication tests
    Suite-ApiInvocation.ps1      # HTTP methods, PUT, DELETE, Full responses
    Suite-TokenManagement.ps1    # Token lifecycle tests
tests/
  safeguardjavaclient/           # Java CLI test tool
```

## Writing Test Suites

Each suite is a `.ps1` file in the `Suites/` directory that returns a hashtable:

```powershell
@{
    Name        = "My Test Suite"
    Description = "What this suite tests"
    Tags        = @("tag1", "tag2")

    Setup = {
        param($Context)
        # Create test objects, register cleanup
        $user = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "Users" -Body @{ Name = "TestUser"; ... }

        Register-SgJTestCleanup -Description "Delete test user" -Action {
            param($Ctx)
            Remove-SgJSafeguardTestObject -Context $Ctx -RelativeUrl "Users/$($user.Id)"
        }
    }

    Execute = {
        param($Context)
        Test-SgJAssert "Test name" { $true }
        Test-SgJAssertEqual "Values match" "expected" "actual"
        Test-SgJAssertNotNull "Has value" $someValue
        Test-SgJAssertThrows "Should fail" { throw "error" }
    }

    Cleanup = {
        param($Context)
        # Registered cleanup runs automatically (LIFO)
    }
}
```

## Available Functions

### API Invocation
- `Invoke-SgJSafeguardApi` — Call Safeguard API (handles auth, JSON, headers)
- `Invoke-SgJTokenCommand` — Token operations (TokenLifetime, GetToken)
- `Invoke-SgJSafeguardTool` — Low-level tool invocation

### Assertions
- `Test-SgJAssert` — Boolean assertion with continue-on-failure
- `Test-SgJAssertEqual` — Equality check
- `Test-SgJAssertNotNull` — Null check
- `Test-SgJAssertContains` — Substring check
- `Test-SgJAssertThrows` — Exception check
- `Test-SgJSkip` — Skip with reason

### Object Management
- `Remove-SgJStaleTestObject` — Remove by name from collection
- `Remove-SgJSafeguardTestObject` — Remove by direct URL
- `Clear-SgJStaleTestEnvironment` — Remove all test-prefixed objects
- `Register-SgJTestCleanup` — Register LIFO cleanup action

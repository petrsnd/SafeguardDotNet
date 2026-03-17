#Requires -Version 7.0
<#
.SYNOPSIS
    SafeguardDotNet Integration Test Runner

.DESCRIPTION
    Discovers and runs test suites from the Suites/ directory against a live
    Safeguard appliance. Each suite follows Setup → Execute → Cleanup lifecycle
    with continue-on-failure semantics and structured reporting.

.PARAMETER Appliance
    Safeguard appliance network address (required).

.PARAMETER AdminUserName
    Bootstrap admin username. Default: "admin".

.PARAMETER AdminPassword
    Bootstrap admin password. Default: "Admin123".

.PARAMETER SpsAppliance
    Optional Safeguard for Privileged Sessions appliance address.

.PARAMETER SpsUser
    SPS admin username. Default: "admin".

.PARAMETER SpsPassword
    SPS admin password.

.PARAMETER Suite
    Run only the specified suite(s) by name. Accepts wildcards.
    Example: -Suite "PasswordAuth","CertificateAuth"

.PARAMETER ExcludeSuite
    Skip the specified suite(s) by name. Accepts wildcards.

.PARAMETER ListSuites
    List available test suites without running them.

.PARAMETER ReportPath
    Optional path to export JSON test report.

.PARAMETER SkipBuild
    Skip building test projects (use when already built).

.PARAMETER TestPrefix
    Prefix for test objects created on the appliance. Default: "SgDnTest".

.EXAMPLE
    # Run all suites
    ./Invoke-SafeguardTests.ps1 -Appliance sg.example.com

.EXAMPLE
    # Run specific suites
    ./Invoke-SafeguardTests.ps1 -Appliance sg.example.com -Suite PasswordAuth,CertificateAuth

.EXAMPLE
    # List available suites
    ./Invoke-SafeguardTests.ps1 -ListSuites
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Appliance,

    [Parameter()]
    [string]$AdminUserName = "admin",

    [Parameter()]
    [string]$AdminPassword = "Admin123",

    [Parameter()]
    [string]$SpsAppliance,

    [Parameter()]
    [string]$SpsUser = "admin",

    [Parameter()]
    [string]$SpsPassword,

    [Parameter()]
    [string[]]$Suite,

    [Parameter()]
    [string[]]$ExcludeSuite,

    [Parameter()]
    [switch]$ListSuites,

    [Parameter()]
    [string]$ReportPath,

    [Parameter()]
    [switch]$SkipBuild,

    [Parameter()]
    [string]$TestPrefix = "SgDnTest"
)

$ErrorActionPreference = "Continue"

# Import the framework module
$frameworkModule = Join-Path $PSScriptRoot "SafeguardTestFramework.psm1"
if (-not (Test-Path $frameworkModule)) {
    Write-Error "Framework module not found: $frameworkModule"
    exit 1
}
Import-Module $frameworkModule -Force

# Discover suite files
$suitesDir = Join-Path $PSScriptRoot "Suites"
if (-not (Test-Path $suitesDir)) {
    Write-Error "Suites directory not found: $suitesDir"
    exit 1
}

$suiteFiles = Get-ChildItem -Path $suitesDir -Filter "Suite-*.ps1" | Sort-Object Name

if ($suiteFiles.Count -eq 0) {
    Write-Warning "No suite files found in $suitesDir"
    if ($ListSuites) { exit 0 }
}

# --- List mode ---
if ($ListSuites) {
    Write-Host ""
    Write-Host "Available Test Suites:" -ForegroundColor Cyan
    Write-Host ("-" * 60) -ForegroundColor DarkGray
    foreach ($file in $suiteFiles) {
        $def = & $file.FullName
        $shortName = $file.BaseName -replace '^Suite-', ''
        $tags = if ($def.Tags) { "[$($def.Tags -join ', ')]" } else { "" }
        Write-Host "  $($shortName.PadRight(30)) $($def.Name)" -ForegroundColor White
        if ($def.Description) {
            Write-Host "    $($def.Description)" -ForegroundColor DarkGray
        }
        if ($tags) {
            Write-Host "    Tags: $tags" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
    exit 0
}

# --- Run mode: Appliance is required ---
if (-not $Appliance) {
    Write-Error "The -Appliance parameter is required when running tests. Use -ListSuites to see available suites."
    exit 1
}

# Filter suites
$selectedSuites = $suiteFiles
if ($Suite) {
    $selectedSuites = $selectedSuites | Where-Object {
        $shortName = $_.BaseName -replace '^Suite-', ''
        $matched = $false
        foreach ($pattern in $Suite) {
            if ($shortName -like $pattern) { $matched = $true; break }
        }
        $matched
    }
}
if ($ExcludeSuite) {
    $selectedSuites = $selectedSuites | Where-Object {
        $shortName = $_.BaseName -replace '^Suite-', ''
        $excluded = $false
        foreach ($pattern in $ExcludeSuite) {
            if ($shortName -like $pattern) { $excluded = $true; break }
        }
        -not $excluded
    }
}

if (-not $selectedSuites -or @($selectedSuites).Count -eq 0) {
    Write-Warning "No suites matched the specified filters."
    exit 0
}

# --- Initialize ---
Write-Host ""
Write-Host ("=" * 66) -ForegroundColor Cyan
Write-Host "  SafeguardDotNet Integration Tests" -ForegroundColor Cyan
Write-Host ("=" * 66) -ForegroundColor Cyan
Write-Host "  Appliance:  $Appliance" -ForegroundColor White
Write-Host "  SPS:        $(if ($SpsAppliance) { $SpsAppliance } else { '(not configured)' })" -ForegroundColor White
Write-Host "  Suites:     $(@($selectedSuites).Count) selected" -ForegroundColor White
Write-Host ("=" * 66) -ForegroundColor Cyan

$context = New-SgDnTestContext `
    -Appliance $Appliance `
    -AdminUserName $AdminUserName `
    -AdminPassword $AdminPassword `
    -SpsAppliance $SpsAppliance `
    -SpsUser $SpsUser `
    -SpsPassword $SpsPassword `
    -TestPrefix $TestPrefix

# --- Build ---
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "Building test projects..." -ForegroundColor Yellow
    try {
        Build-SgDnTestProjects -Context $context
        Write-Host "  Build complete." -ForegroundColor Green
    }
    catch {
        Write-Host "  Build failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# --- Ensure resource owner password grant is enabled ---
Write-Host ""
Write-Host "Preflight: checking resource owner password grant..." -ForegroundColor Yellow
$rogEnabled = $false
try {
    $rstsResponse = Invoke-WebRequest -Uri "https://$Appliance/RSTS/oauth2/token" `
        -Method Post -ContentType "application/x-www-form-urlencoded" `
        -Body "grant_type=password&username=$AdminUserName&password=$AdminPassword&scope=rsts:sts:primaryproviderid:local" `
        -SkipCertificateCheck -SkipHttpErrorCheck -ErrorAction Stop
    $rstsBody = $rstsResponse.Content | ConvertFrom-Json
    if ($rstsResponse.StatusCode -eq 200 -and $rstsBody.access_token) {
        Write-Host "  Resource owner grant is enabled." -ForegroundColor Green
        $rogEnabled = $true
    } elseif ($rstsBody.error_description -match "not allowed") {
        Write-Host "  Resource owner grant is disabled. Enabling via PKCE..." -ForegroundColor Yellow
    } else {
        Write-Host "  Unexpected RSTS response ($($rstsResponse.StatusCode)): $($rstsResponse.Content)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  Failed to reach RSTS: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$resourceOwnerWasDisabled = $false
if (-not $rogEnabled) {
    try {
        $pkceResult = Invoke-SgDnSafeguardTool `
            -ProjectDir $context.PkceToolDir `
            -Arguments "-a $Appliance -x -u $AdminUserName -p -R true" `
            -StdinLine $AdminPassword `
            -ParseJson $true
        Write-Host "  Enabled resource owner grant (was: '$($pkceResult.PreviousValue)')." -ForegroundColor Green
        $resourceOwnerWasDisabled = $true
    } catch {
        Write-Host "  Failed to enable resource owner grant: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# --- Global pre-cleanup ---
Write-Host ""
Write-Host "Pre-cleanup: removing stale objects from previous runs..." -ForegroundColor Yellow
Clear-SgDnStaleTestEnvironment -Context $context

# --- Run suites ---
foreach ($suiteFile in $selectedSuites) {
    Invoke-SgDnTestSuite -SuiteFile $suiteFile.FullName -Context $context
}

# --- Report ---
$failCount = Write-SgDnTestReport -Context $context

if ($ReportPath) {
    Export-SgDnTestReport -OutputPath $ReportPath -Context $context
}

# --- Restore resource owner grant setting if we changed it ---
if ($resourceOwnerWasDisabled) {
    Write-Host ""
    Write-Host "Restoring: disabling resource owner grant (was disabled before tests)..." -ForegroundColor Yellow
    try {
        $null = Invoke-SgDnSafeguardTool `
            -ProjectDir $context.PkceToolDir `
            -Arguments "-a $Appliance -x -u $AdminUserName -p -R false" `
            -StdinLine $AdminPassword `
            -ParseJson $true
        Write-Host "  Resource owner grant restored to disabled." -ForegroundColor Green
    } catch {
        Write-Host "  Warning: failed to restore resource owner grant: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# Exit with appropriate code for CI
if ($failCount -gt 0) {
    exit 1
}
exit 0

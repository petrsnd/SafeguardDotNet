#Requires -Version 7.0
<#
.SYNOPSIS
    SafeguardJava Integration Test Runner

.DESCRIPTION
    Discovers and runs test suites from the Suites/ directory against a live
    Safeguard appliance. Each suite follows Setup -> Execute -> Cleanup lifecycle
    with continue-on-failure semantics and structured reporting.

.PARAMETER Appliance
    Safeguard appliance network address (required).

.PARAMETER AdminUserName
    Bootstrap admin username. Default: "admin".

.PARAMETER AdminPassword
    Bootstrap admin password. Default: "Admin123".

.PARAMETER Suite
    Run only the specified suite(s) by name. Accepts wildcards.

.PARAMETER ExcludeSuite
    Skip the specified suite(s) by name. Accepts wildcards.

.PARAMETER ListSuites
    List available test suites without running them.

.PARAMETER ReportPath
    Optional path to export JSON test report.

.PARAMETER SkipBuild
    Skip building test projects (use when already built).

.PARAMETER TestPrefix
    Prefix for test objects created on the appliance. Default: "SgJTest".

.PARAMETER MavenCmd
    Path to the Maven command. Defaults to searching PATH then common locations.

.EXAMPLE
    ./Invoke-SafeguardTests.ps1 -Appliance 192.168.117.15 -AdminPassword root4EDMZ

.EXAMPLE
    ./Invoke-SafeguardTests.ps1 -Appliance sg.example.com -Suite PasswordAuth,AnonymousAccess

.EXAMPLE
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
    [string]$TestPrefix = "SgJTest",

    [Parameter()]
    [string]$MavenCmd
)

$ErrorActionPreference = "Continue"

# Find Maven if not specified
if (-not $MavenCmd) {
    $MavenCmd = Get-Command mvn -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if (-not $MavenCmd) {
        $MavenCmd = Get-Command mvn.cmd -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    }
    if (-not $MavenCmd -and $env:M2_HOME) {
        $c = Join-Path $env:M2_HOME "bin" "mvn.cmd"
        if (Test-Path $c) { $MavenCmd = $c }
    }
    if (-not $MavenCmd) {
        # Search common locations for any installed Maven version
        $searchDirs = @(
            "$env:USERPROFILE\tools"
            "C:\tools"
            "C:\Program Files\Apache\Maven"
            "C:\Program Files (x86)\Apache\Maven"
        )
        foreach ($dir in $searchDirs) {
            if (Test-Path $dir) {
                $found = Get-ChildItem -Path $dir -Filter "apache-maven-*" -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending | Select-Object -First 1
                if ($found) {
                    $c = Join-Path $found.FullName "bin" "mvn.cmd"
                    if (Test-Path $c) { $MavenCmd = $c; break }
                }
            }
        }
    }
    if (-not $MavenCmd) {
        Write-Error "Maven not found. Provide -MavenCmd or add Maven to PATH."
        exit 1
    }
}

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
Write-Host "  SafeguardJava Integration Tests" -ForegroundColor Cyan
Write-Host ("=" * 66) -ForegroundColor Cyan
Write-Host "  Appliance:  $Appliance" -ForegroundColor White
Write-Host "  Maven:      $MavenCmd" -ForegroundColor White
Write-Host "  Suites:     $(@($selectedSuites).Count) selected" -ForegroundColor White
Write-Host ("=" * 66) -ForegroundColor Cyan

$context = New-SgJTestContext `
    -Appliance $Appliance `
    -AdminUserName $AdminUserName `
    -AdminPassword $AdminPassword `
    -TestPrefix $TestPrefix `
    -MavenCmd $MavenCmd

# --- Build ---
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "Building test projects..." -ForegroundColor Yellow
    try {
        Build-SgJTestProjects -Context $context
        Write-Host "  Build complete." -ForegroundColor Green
    }
    catch {
        Write-Host "  Build failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# --- Global pre-cleanup ---
Write-Host ""
Write-Host "Pre-cleanup: removing stale objects from previous runs..." -ForegroundColor Yellow
Clear-SgJStaleTestEnvironment -Context $context

# --- Run suites ---
foreach ($suiteFile in $selectedSuites) {
    Invoke-SgJTestSuite -SuiteFile $suiteFile.FullName -Context $context
}

# --- Report ---
$failCount = Write-SgJTestReport -Context $context

if ($ReportPath) {
    Export-SgJTestReport -OutputPath $ReportPath -Context $context
}

# Exit with appropriate code for CI
if ($failCount -gt 0) {
    exit 1
}
exit 0

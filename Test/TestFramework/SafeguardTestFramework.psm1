#Requires -Version 7.0
<#
.SYNOPSIS
    SafeguardDotNet Test Framework Module

.DESCRIPTION
    Provides test context management, assertion functions, improved tool invocation,
    cleanup registration, and structured reporting for SafeguardDotNet integration tests.

    All tests run against a live Safeguard appliance. This module replaces the fragile
    Invoke-Expression / regex-based patterns from the legacy test script with proper
    process invocation using Start-Process and exit code checking.

    All exported functions use the SgDn noun prefix to avoid conflicts.
#>

# ============================================================================
# Module-scoped state
# ============================================================================

$script:TestContext = $null

# ============================================================================
# Context Management
# ============================================================================

function New-SgDnTestContext {
    <#
    .SYNOPSIS
        Creates a new test context tracking appliance info, credentials, results, and cleanup.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
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
        [string]$TestPrefix = "SgDnTest"
    )

    $testRoot = Split-Path -Parent $PSScriptRoot
    $context = [PSCustomObject]@{
        # Connection info
        Appliance       = $Appliance
        AdminUserName   = $AdminUserName
        AdminPassword   = $AdminPassword
        SpsAppliance    = $SpsAppliance
        SpsUser         = $SpsUser
        SpsPassword     = $SpsPassword

        # Naming
        TestPrefix      = $TestPrefix

        # Paths
        TestRoot        = $testRoot
        ToolDir         = (Join-Path $testRoot "SafeguardDotNetTool")
        ExceptionTestDir = (Join-Path $testRoot "SafeguardDotNetExceptionTest")
        A2aToolDir      = (Join-Path $testRoot "SafeguardDotNetA2aTool")
        AccessRequestBrokerToolDir = (Join-Path $testRoot "SafeguardDotNetAccessRequestBrokerTool")
        EventToolDir    = (Join-Path $testRoot "SafeguardDotNetEventTool")
        SessionsToolDir = (Join-Path $testRoot "SafeguardSessionsDotNetTool")
        CertDir         = (Join-Path $testRoot "TestData" "CERTS")

        # Per-suite transient data (reset each suite)
        SuiteData       = @{}

        # Cleanup stack (LIFO)
        CleanupActions  = [System.Collections.Generic.Stack[PSCustomObject]]::new()

        # Results
        SuiteResults    = [System.Collections.Generic.List[PSCustomObject]]::new()
        StartTime       = [DateTime]::UtcNow
    }

    # Resolve certificate paths
    $context | Add-Member -NotePropertyName UserCert -NotePropertyValue (Join-Path $context.CertDir "UserCert.pem")
    $context | Add-Member -NotePropertyName UserPfx  -NotePropertyValue (Join-Path $context.CertDir "UserCert.pfx")
    $context | Add-Member -NotePropertyName RootCert -NotePropertyValue (Join-Path $context.CertDir "RootCA.pem")
    $context | Add-Member -NotePropertyName CaCert   -NotePropertyValue (Join-Path $context.CertDir "IntermediateCA.pem")

    $script:TestContext = $context
    return $context
}

function Get-SgDnTestContext {
    <#
    .SYNOPSIS
        Returns the current module-scoped test context.
    #>
    if (-not $script:TestContext) {
        throw "No test context. Call New-SgDnTestContext first."
    }
    return $script:TestContext
}

# ============================================================================
# Cleanup Registration
# ============================================================================

function Register-SgDnTestCleanup {
    <#
    .SYNOPSIS
        Registers an idempotent cleanup action that runs during suite cleanup.
        Actions execute in LIFO order. Failures are logged but do not propagate.
    .PARAMETER Description
        Human-readable description of what this cleanup does.
    .PARAMETER Action
        ScriptBlock to execute. Receives $Context as parameter.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Description,

        [Parameter(Mandatory)]
        [scriptblock]$Action
    )

    $ctx = Get-SgDnTestContext
    $ctx.CleanupActions.Push([PSCustomObject]@{
        Description = $Description
        Action      = $Action
    })
}

function Invoke-SgDnTestCleanup {
    <#
    .SYNOPSIS
        Executes all registered cleanup actions in LIFO order.
        Each action is wrapped in try/catch — failures are logged but never propagate.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Context
    )

    $count = $Context.CleanupActions.Count
    if ($count -eq 0) {
        Write-Host "  No cleanup actions registered." -ForegroundColor DarkGray
        return
    }

    Write-Host "  Running $count cleanup action(s)..." -ForegroundColor DarkGray
    while ($Context.CleanupActions.Count -gt 0) {
        $item = $Context.CleanupActions.Pop()
        try {
            Write-Host "    Cleanup: $($item.Description)" -ForegroundColor DarkGray
            & $item.Action $Context
        }
        catch {
            Write-Host "    Cleanup ignored failure: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }
}

# ============================================================================
# Tool Invocation (improved from legacy Invoke-DotNetRun)
# ============================================================================

function Invoke-SgDnSafeguardTool {
    <#
    .SYNOPSIS
        Runs a dotnet test tool project with proper process management.

        Replaces the legacy Invoke-Expression + regex approach with Start-Process
        for clean stdin/stdout/stderr separation and exit code checking.

    .PARAMETER ProjectDir
        Path to the dotnet project directory.

    .PARAMETER Arguments
        Arguments string to pass after 'dotnet run --'.

    .PARAMETER StdinLine
        Optional single line to pipe to stdin (typically a password).
        Only used by tools that accept -p/--ReadPassword.

    .PARAMETER ParseJson
        If set, attempts to parse stdout as JSON. Default: $true.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for the process. Default: 120.

    .RETURNS
        PSObject if JSON parsed successfully, or raw string output.
        Throws on non-zero exit code.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectDir,

        [Parameter()]
        [string]$Arguments = "",

        [Parameter()]
        [string]$StdinLine,

        [Parameter()]
        [bool]$ParseJson = $true,

        [Parameter()]
        [int]$TimeoutSeconds = 120
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = "dotnet"
    $startInfo.Arguments = "run --project `"$ProjectDir`" -- $Arguments"
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardInput = ($null -ne $StdinLine -and $StdinLine -ne "")
    $startInfo.CreateNoWindow = $true
    $startInfo.WorkingDirectory = $ProjectDir

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo

    # Capture output asynchronously to avoid deadlocks
    $stdoutBuilder = [System.Text.StringBuilder]::new()
    $stderrBuilder = [System.Text.StringBuilder]::new()

    $stdoutEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
        if ($null -ne $EventArgs.Data) {
            $Event.MessageData.AppendLine($EventArgs.Data) | Out-Null
        }
    } -MessageData $stdoutBuilder

    $stderrEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
        if ($null -ne $EventArgs.Data) {
            $Event.MessageData.AppendLine($EventArgs.Data) | Out-Null
        }
    } -MessageData $stderrBuilder

    try {
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        if ($startInfo.RedirectStandardInput) {
            $process.StandardInput.WriteLine($StdinLine)
            $process.StandardInput.Close()
        }

        $exited = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $exited) {
            try { $process.Kill() } catch {}
            throw "Process timed out after ${TimeoutSeconds}s: dotnet run --project `"$ProjectDir`" -- $Arguments"
        }

        # Allow async output events to flush
        $process.WaitForExit()
    }
    finally {
        Unregister-Event -SourceIdentifier $stdoutEvent.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $stderrEvent.Name -ErrorAction SilentlyContinue
        Remove-Job -Name $stdoutEvent.Name -Force -ErrorAction SilentlyContinue
        Remove-Job -Name $stderrEvent.Name -Force -ErrorAction SilentlyContinue
    }

    $stdout = $stdoutBuilder.ToString().Trim()
    $stderr = $stderrBuilder.ToString().Trim()
    $exitCode = $process.ExitCode
    $process.Dispose()

    if ($exitCode -ne 0) {
        $errorDetail = if ($stderr) { $stderr } elseif ($stdout) { $stdout } else { "Exit code $exitCode" }
        throw "Tool failed (exit code $exitCode): $errorDetail"
    }

    if (-not $ParseJson -or [string]::IsNullOrWhiteSpace($stdout)) {
        return $stdout
    }

    # Parse JSON from stdout, filtering out dotnet SDK noise lines.
    # The dotnet CLI sometimes emits build/restore messages before the tool output.
    $lines = $stdout -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

    # Try parsing the entire output as JSON first (most common case)
    try {
        return ($stdout | ConvertFrom-Json)
    }
    catch {
        # Fall through to line-by-line parsing
    }

    # Try each line — find the last valid JSON line (tools sometimes emit logs before JSON)
    $jsonResult = $null
    foreach ($line in $lines) {
        try {
            $jsonResult = $line | ConvertFrom-Json
        }
        catch {
            # Not JSON — skip (likely dotnet SDK output or Serilog log line)
        }
    }

    if ($null -ne $jsonResult) {
        return $jsonResult
    }

    # No JSON found — return raw string
    return $stdout
}

function Invoke-SgDnSafeguardApi {
    <#
    .SYNOPSIS
        Convenience wrapper for calling Safeguard API via SafeguardDotNetTool.

    .DESCRIPTION
        Builds the argument string for SafeguardDotNetTool and invokes it.
        Handles the common patterns: appliance, auth, service, method, URL, body.

    .PARAMETER Context
        Test context (from New-SgDnTestContext). If omitted, uses module-scoped context.

    .PARAMETER Service
        Safeguard service: Core, Appliance, Notification, A2A.

    .PARAMETER Method
        HTTP method: Get, Post, Put, Delete.

    .PARAMETER RelativeUrl
        API endpoint relative URL.

    .PARAMETER Body
        Optional request body. Hashtables are auto-converted to JSON with single-quote escaping.

    .PARAMETER Username
        Username for password auth. If omitted, uses context AdminUserName.

    .PARAMETER Password
        Password for auth. If omitted, uses context AdminPassword.

    .PARAMETER CertificateFile
        Path to PFX file for certificate auth (overrides username/password).

    .PARAMETER CertificatePassword
        Password for the PFX file.

    .PARAMETER CertificateAsData
        Load PFX as data buffer instead of file path.

    .PARAMETER Thumbprint
        Certificate thumbprint for cert store auth (overrides username/password and cert file).

    .PARAMETER Anonymous
        Use anonymous authentication (no credentials).

    .PARAMETER Csv
        Request CSV format response.

    .PARAMETER ParseJson
        Whether to parse the response as JSON. Default: $true.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSCustomObject]$Context,

        [Parameter(Mandatory)]
        [ValidateSet("Core", "Appliance", "Notification", "A2A")]
        [string]$Service,

        [Parameter(Mandatory)]
        [ValidateSet("Get", "Post", "Put", "Delete")]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$RelativeUrl,

        [Parameter()]
        $Body,

        [Parameter()]
        [string]$Username,

        [Parameter()]
        [string]$Password,

        [Parameter()]
        [string]$CertificateFile,

        [Parameter()]
        [string]$CertificatePassword,

        [Parameter()]
        [switch]$CertificateAsData,

        [Parameter()]
        [string]$Thumbprint,

        [Parameter()]
        [switch]$Anonymous,

        [Parameter()]
        [switch]$Csv,

        [Parameter()]
        [bool]$ParseJson = $true
    )

    if (-not $Context) { $Context = Get-SgDnTestContext }

    $toolArgs = "-a $($Context.Appliance) -x -s $Service -m $Method -U `"$RelativeUrl`""

    $stdinLine = $null

    if ($Anonymous) {
        $toolArgs += " -A"
    }
    elseif ($Thumbprint) {
        $toolArgs += " -t $Thumbprint -p"
        # Thumbprint auth still needs a password for the cert (or empty)
        $stdinLine = if ($CertificatePassword) { $CertificatePassword } else { "" }
    }
    elseif ($CertificateFile) {
        $toolArgs += " -c `"$CertificateFile`" -p"
        if ($CertificateAsData) { $toolArgs += " -d" }
        $stdinLine = if ($CertificatePassword) { $CertificatePassword } else { "" }
    }
    else {
        $effectiveUser = if ($Username) { $Username } else { $Context.AdminUserName }
        $effectivePass = if ($Password) { $Password } else { $Context.AdminPassword }
        $toolArgs += " -u $effectiveUser -p"
        $stdinLine = $effectivePass
    }

    if ($Body) {
        $bodyStr = if ($Body -is [hashtable] -or $Body -is [System.Collections.IDictionary]) {
            (ConvertTo-Json -Depth 12 $Body -Compress).Replace('"', "'")
        }
        elseif ($Body -is [PSCustomObject]) {
            (ConvertTo-Json -Depth 12 $Body -Compress).Replace('"', "'")
        }
        else {
            [string]$Body
        }
        $toolArgs += " -b `"$bodyStr`""
    }

    if ($Csv) { $toolArgs += " -C" }

    Write-Verbose "Invoke-SgDnSafeguardApi: dotnet run -- $toolArgs"

    return Invoke-SgDnSafeguardTool -ProjectDir $Context.ToolDir -Arguments $toolArgs -StdinLine $stdinLine -ParseJson $ParseJson
}

function Invoke-SgDnSafeguardA2aTool {
    <#
    .SYNOPSIS
        Convenience wrapper for calling SafeguardDotNetA2aTool.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSCustomObject]$Context,

        [Parameter(Mandatory)]
        [string]$ApiKey,

        [Parameter()]
        [string]$CertificateFile,

        [Parameter()]
        [string]$CertificatePassword,

        [Parameter()]
        [switch]$CertificateAsData,

        [Parameter()]
        [string]$Thumbprint,

        [Parameter()]
        [switch]$RetrievableAccounts,

        [Parameter()]
        [switch]$NewPassword,

        [Parameter()]
        [switch]$PrivateKey,

        [Parameter()]
        [switch]$ApiKeySecret,

        [Parameter()]
        [string]$KeyFormat,

        [Parameter()]
        [bool]$ParseJson = $true
    )

    if (-not $Context) { $Context = Get-SgDnTestContext }

    $toolArgs = "-a $($Context.Appliance) -x -A `"$ApiKey`""

    $stdinLine = $null

    if ($Thumbprint) {
        $toolArgs += " -t $Thumbprint -p"
        $stdinLine = if ($CertificatePassword) { $CertificatePassword } else { "" }
    }
    elseif ($CertificateFile) {
        $toolArgs += " -c `"$CertificateFile`" -p"
        if ($CertificateAsData) { $toolArgs += " -d" }
        $stdinLine = if ($CertificatePassword) { $CertificatePassword } else { "" }
    }

    if ($RetrievableAccounts) { $toolArgs += " -R" }
    if ($NewPassword) { $toolArgs += " -N" }
    if ($PrivateKey) { $toolArgs += " -K" }
    if ($ApiKeySecret) { $toolArgs += " -P" }
    if ($KeyFormat) { $toolArgs += " -F $KeyFormat" }

    Write-Verbose "Invoke-SgDnSafeguardA2aTool: dotnet run -- $toolArgs"

    return Invoke-SgDnSafeguardTool -ProjectDir $Context.A2aToolDir -Arguments $toolArgs -StdinLine $stdinLine -ParseJson $ParseJson
}

function Invoke-SgDnSafeguardSessionsTool {
    <#
    .SYNOPSIS
        Convenience wrapper for calling SafeguardSessionsDotNetTool.
        Note: This tool takes password as a CLI argument, not stdin.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSCustomObject]$Context,

        [Parameter(Mandatory)]
        [ValidateSet("Get", "Post", "Put", "Delete", "Patch")]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$RelativeUrl,

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [string]$Username,

        [Parameter()]
        [string]$Password,

        [Parameter()]
        [bool]$ParseJson = $true
    )

    if (-not $Context) { $Context = Get-SgDnTestContext }

    $effectiveUser = if ($Username) { $Username } else { $Context.SpsUser }
    $effectivePass = if ($Password) { $Password } else { $Context.SpsPassword }

    $toolArgs = "-a $($Context.SpsAppliance) -k -u $effectiveUser -p $effectivePass -m $Method -U `"$RelativeUrl`""
    if ($Body) { $toolArgs += " -b `"$Body`"" }

    Write-Verbose "Invoke-SgDnSafeguardSessionsTool: dotnet run -- $toolArgs"

    # Sessions tool does NOT read from stdin
    return Invoke-SgDnSafeguardTool -ProjectDir $Context.SessionsToolDir -Arguments $toolArgs -ParseJson $ParseJson
}

# ============================================================================
# Build Helpers
# ============================================================================

function Build-SgDnTestProjects {
    <#
    .SYNOPSIS
        Builds all test tool projects. Throws on build failure.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSCustomObject]$Context,

        [Parameter()]
        [string[]]$Projects
    )

    if (-not $Context) { $Context = Get-SgDnTestContext }

    $defaultProjects = @(
        $Context.ToolDir
        $Context.ExceptionTestDir
        $Context.A2aToolDir
        $Context.AccessRequestBrokerToolDir
        $Context.EventToolDir
    )

    $toBuild = if ($Projects) { $Projects } else { $defaultProjects }

    foreach ($projectDir in $toBuild) {
        $projectName = Split-Path $projectDir -Leaf
        Write-Host "  Building $projectName..." -ForegroundColor DarkCyan
        $result = & dotnet build $projectDir --nologo --verbosity quiet 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed for $projectName`n$($result -join "`n")"
        }
    }
}

# ============================================================================
# Assertion Functions
# ============================================================================

function Test-SgDnAssert {
    <#
    .SYNOPSIS
        Records a named test result. Pass a scriptblock that returns $true/$false or throws.
    .EXAMPLE
        Test-SgDnAssert "User can log in" { (Invoke-SgDnSafeguardApi ...).Name -eq "admin" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$Test
    )

    $ctx = Get-SgDnTestContext
    $result = [PSCustomObject]@{
        Name      = $Name
        Status    = "Unknown"
        Message   = ""
        Duration  = [TimeSpan]::Zero
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $testResult = & $Test
        $sw.Stop()
        $result.Duration = $sw.Elapsed

        if ($testResult -eq $false) {
            $result.Status = "Fail"
            $result.Message = "Assertion returned `$false"
            Write-Host "    FAIL: $Name — Assertion returned `$false" -ForegroundColor Red
        }
        else {
            $result.Status = "Pass"
            Write-Host "    PASS: $Name" -ForegroundColor Green
        }
    }
    catch {
        $sw.Stop()
        $result.Duration = $sw.Elapsed
        $result.Status = "Fail"
        $result.Message = $_.Exception.Message
        Write-Host "    FAIL: $Name — $($_.Exception.Message)" -ForegroundColor Red
    }

    # Append to current suite's test results (stored temporarily on context)
    if (-not $ctx.SuiteData.ContainsKey('_TestResults')) {
        $ctx.SuiteData['_TestResults'] = [System.Collections.Generic.List[PSCustomObject]]::new()
    }
    $ctx.SuiteData['_TestResults'].Add($result)
}

function Test-SgDnAssertEqual {
    <#
    .SYNOPSIS
        Asserts two values are equal.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        $Expected,

        [Parameter(Mandatory, Position = 2)]
        $Actual
    )

    Test-SgDnAssert $Name {
        if ($Expected -ne $Actual) {
            throw "Expected '$Expected' but got '$Actual'"
        }
        $true
    }
}

function Test-SgDnAssertNotNull {
    <#
    .SYNOPSIS
        Asserts a value is not null or empty.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Position = 1)]
        $Value
    )

    Test-SgDnAssert $Name {
        if ($null -eq $Value -or ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value))) {
            throw "Value was null or empty"
        }
        $true
    }
}

function Test-SgDnAssertContains {
    <#
    .SYNOPSIS
        Asserts a string contains a substring, or a collection contains an element.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        $Haystack,

        [Parameter(Mandatory, Position = 2)]
        $Needle
    )

    Test-SgDnAssert $Name {
        if ($Haystack -is [string]) {
            if (-not $Haystack.Contains($Needle)) {
                throw "String does not contain '$Needle'"
            }
        }
        elseif ($Haystack -is [System.Collections.IEnumerable]) {
            if ($Needle -notin $Haystack) {
                throw "Collection does not contain '$Needle'"
            }
        }
        else {
            throw "Unsupported haystack type: $($Haystack.GetType().Name)"
        }
        $true
    }
}

function Test-SgDnAssertThrows {
    <#
    .SYNOPSIS
        Asserts that a scriptblock throws an exception.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [scriptblock]$Action,

        [Parameter()]
        [string]$ExpectedMessage
    )

    Test-SgDnAssert $Name {
        $threw = $false
        try {
            & $Action
        }
        catch {
            $threw = $true
            if ($ExpectedMessage -and $_.Exception.Message -notlike "*$ExpectedMessage*") {
                throw "Expected exception containing '$ExpectedMessage' but got: $($_.Exception.Message)"
            }
        }
        if (-not $threw) {
            throw "Expected an exception but none was thrown"
        }
        $true
    }
}

function Test-SgDnSkip {
    <#
    .SYNOPSIS
        Records a named test as skipped with a reason.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, Position = 1)]
        [string]$Reason
    )

    $ctx = Get-SgDnTestContext
    $result = [PSCustomObject]@{
        Name     = $Name
        Status   = "Skip"
        Message  = $Reason
        Duration = [TimeSpan]::Zero
    }

    Write-Host "    SKIP: $Name — $Reason" -ForegroundColor Yellow

    if (-not $ctx.SuiteData.ContainsKey('_TestResults')) {
        $ctx.SuiteData['_TestResults'] = [System.Collections.Generic.List[PSCustomObject]]::new()
    }
    $ctx.SuiteData['_TestResults'].Add($result)
}

# ============================================================================
# Suite Execution
# ============================================================================

function Invoke-SgDnTestSuite {
    <#
    .SYNOPSIS
        Runs a single test suite through Setup → Execute → Cleanup.
        Failures in Setup or Execute do not prevent Cleanup from running.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SuiteFile,

        [Parameter()]
        [PSCustomObject]$Context
    )

    if (-not $Context) { $Context = Get-SgDnTestContext }

    # Load suite definition
    $suite = & $SuiteFile
    if (-not $suite -or -not $suite.Name) {
        Write-Host "  ERROR: Invalid suite file: $SuiteFile" -ForegroundColor Red
        return
    }

    $suiteName = $suite.Name
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Suite: $suiteName" -ForegroundColor Cyan
    if ($suite.Description) {
        Write-Host "  $($suite.Description)" -ForegroundColor DarkCyan
    }
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan

    # Reset per-suite state
    $Context.SuiteData = @{}
    $Context.SuiteData['_TestResults'] = [System.Collections.Generic.List[PSCustomObject]]::new()
    $Context.CleanupActions = [System.Collections.Generic.Stack[PSCustomObject]]::new()

    $suiteResult = [PSCustomObject]@{
        Name         = $suiteName
        SetupError   = $null
        ExecuteError = $null
        CleanupError = $null
        Tests        = [System.Collections.Generic.List[PSCustomObject]]::new()
        Duration     = [TimeSpan]::Zero
    }

    $suiteSw = [System.Diagnostics.Stopwatch]::StartNew()

    # --- Setup ---
    if ($suite.Setup) {
        Write-Host "  [Setup]" -ForegroundColor DarkGray
        try {
            & $suite.Setup $Context
        }
        catch {
            $suiteResult.SetupError = $_.Exception.Message
            Write-Host "  SETUP FAILED: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # --- Execute (only if setup succeeded) ---
    if (-not $suiteResult.SetupError -and $suite.Execute) {
        Write-Host "  [Execute]" -ForegroundColor DarkGray
        try {
            & $suite.Execute $Context
        }
        catch {
            $suiteResult.ExecuteError = $_.Exception.Message
            Write-Host "  EXECUTE ERROR: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    elseif ($suiteResult.SetupError) {
        Write-Host "  [Execute] Skipped due to setup failure" -ForegroundColor Yellow
    }

    # --- Cleanup (always runs) ---
    Write-Host "  [Cleanup]" -ForegroundColor DarkGray
    try {
        if ($suite.Cleanup) {
            & $suite.Cleanup $Context
        }
    }
    catch {
        $suiteResult.CleanupError = $_.Exception.Message
        Write-Host "  CLEANUP ERROR: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
    # Run registered cleanup actions regardless
    Invoke-SgDnTestCleanup -Context $Context

    $suiteSw.Stop()
    $suiteResult.Duration = $suiteSw.Elapsed

    # Collect test results from this suite
    if ($Context.SuiteData.ContainsKey('_TestResults')) {
        foreach ($tr in $Context.SuiteData['_TestResults']) {
            $suiteResult.Tests.Add($tr)
        }
    }

    # If setup failed and no tests were recorded, add a synthetic failure
    if ($suiteResult.SetupError -and $suiteResult.Tests.Count -eq 0) {
        $suiteResult.Tests.Add([PSCustomObject]@{
            Name     = "Suite Setup"
            Status   = "Fail"
            Message  = "Setup failed: $($suiteResult.SetupError)"
            Duration = [TimeSpan]::Zero
        })
    }

    $pass = ($suiteResult.Tests | Where-Object Status -eq "Pass").Count
    $fail = ($suiteResult.Tests | Where-Object Status -eq "Fail").Count
    $skip = ($suiteResult.Tests | Where-Object Status -eq "Skip").Count
    $statusColor = if ($fail -gt 0) { "Red" } elseif ($skip -gt 0) { "Yellow" } else { "Green" }
    Write-Host "  Result: $pass passed, $fail failed, $skip skipped ($([math]::Round($suiteResult.Duration.TotalSeconds, 1))s)" -ForegroundColor $statusColor
    Write-Host ""

    $Context.SuiteResults.Add($suiteResult)
}

# ============================================================================
# Reporting
# ============================================================================

function Write-SgDnTestReport {
    <#
    .SYNOPSIS
        Writes a formatted test report to the console.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSCustomObject]$Context
    )

    if (-not $Context) { $Context = Get-SgDnTestContext }

    $totalDuration = [DateTime]::UtcNow - $Context.StartTime

    Write-Host ""
    Write-Host ("=" * 66) -ForegroundColor Cyan
    Write-Host "  SafeguardDotNet Test Report" -ForegroundColor Cyan
    Write-Host ("=" * 66) -ForegroundColor Cyan
    Write-Host "  Appliance: $($Context.Appliance)" -ForegroundColor White
    Write-Host "  Duration:  $([math]::Floor($totalDuration.TotalMinutes))m $($totalDuration.Seconds)s" -ForegroundColor White
    Write-Host ("-" * 66) -ForegroundColor DarkGray

    $totalPass = 0
    $totalFail = 0
    $totalSkip = 0

    # Suite summary table
    $headerFmt = "  {0,-36} {1,5} {2,5} {3,5} {4,6}"
    Write-Host ($headerFmt -f "Suite", "Pass", "Fail", "Skip", "Total") -ForegroundColor White
    Write-Host ("-" * 66) -ForegroundColor DarkGray

    foreach ($suite in $Context.SuiteResults) {
        $pass = ($suite.Tests | Where-Object Status -eq "Pass").Count
        $fail = ($suite.Tests | Where-Object Status -eq "Fail").Count
        $skip = ($suite.Tests | Where-Object Status -eq "Skip").Count
        $total = $suite.Tests.Count

        $totalPass += $pass
        $totalFail += $fail
        $totalSkip += $skip

        $color = if ($fail -gt 0) { "Red" } elseif ($skip -gt 0) { "Yellow" } else { "Green" }
        Write-Host ($headerFmt -f $suite.Name, $pass, $fail, $skip, $total) -ForegroundColor $color
    }

    $grandTotal = $totalPass + $totalFail + $totalSkip
    Write-Host ("-" * 66) -ForegroundColor DarkGray
    Write-Host ($headerFmt -f "TOTAL", $totalPass, $totalFail, $totalSkip, $grandTotal) -ForegroundColor White

    if ($grandTotal -gt 0) {
        $passRate = [math]::Round(($totalPass / $grandTotal) * 100, 1)
        $execTotal = $totalPass + $totalFail
        $execPassRate = if ($execTotal -gt 0) { [math]::Round(($totalPass / $execTotal) * 100, 1) } else { 0 }
        Write-Host "  Pass Rate: ${passRate}%    (excluding skipped: ${execPassRate}%)" -ForegroundColor White
    }

    # List failures
    $failures = foreach ($suite in $Context.SuiteResults) {
        foreach ($test in $suite.Tests) {
            if ($test.Status -eq "Fail") {
                [PSCustomObject]@{
                    Suite   = $suite.Name
                    Test    = $test.Name
                    Message = $test.Message
                }
            }
        }
    }

    if ($failures) {
        Write-Host ""
        Write-Host ("-" * 66) -ForegroundColor DarkGray
        Write-Host "  FAILURES:" -ForegroundColor Red
        foreach ($f in $failures) {
            Write-Host "    [$($f.Suite)] $($f.Test)" -ForegroundColor Red
            if ($f.Message) {
                Write-Host "      $($f.Message)" -ForegroundColor DarkRed
            }
        }
    }

    Write-Host ("=" * 66) -ForegroundColor Cyan
    Write-Host ""

    return $totalFail
}

function Export-SgDnTestReport {
    <#
    .SYNOPSIS
        Exports test results to a JSON file for CI integration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter()]
        [PSCustomObject]$Context
    )

    if (-not $Context) { $Context = Get-SgDnTestContext }

    $report = [PSCustomObject]@{
        Appliance = $Context.Appliance
        StartTime = $Context.StartTime.ToString("o")
        EndTime   = [DateTime]::UtcNow.ToString("o")
        Suites    = foreach ($suite in $Context.SuiteResults) {
            [PSCustomObject]@{
                Name       = $suite.Name
                DurationMs = [math]::Round($suite.Duration.TotalMilliseconds)
                SetupError = $suite.SetupError
                Tests      = foreach ($test in $suite.Tests) {
                    [PSCustomObject]@{
                        Name       = $test.Name
                        Status     = $test.Status
                        Message    = $test.Message
                        DurationMs = [math]::Round($test.Duration.TotalMilliseconds)
                    }
                }
            }
        }
        Summary = [PSCustomObject]@{
            TotalPass = ($Context.SuiteResults | ForEach-Object { ($_.Tests | Where-Object Status -eq "Pass").Count } | Measure-Object -Sum).Sum
            TotalFail = ($Context.SuiteResults | ForEach-Object { ($_.Tests | Where-Object Status -eq "Fail").Count } | Measure-Object -Sum).Sum
            TotalSkip = ($Context.SuiteResults | ForEach-Object { ($_.Tests | Where-Object Status -eq "Skip").Count } | Measure-Object -Sum).Sum
        }
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Host "Test report exported to: $OutputPath" -ForegroundColor DarkCyan
}

# ============================================================================
# Safeguard Object Helpers
# ============================================================================

function Remove-SgDnSafeguardTestObject {
    <#
    .SYNOPSIS
        Idempotent delete — removes an object if it exists, silently ignores if not found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Context,

        [Parameter(Mandatory)]
        [string]$RelativeUrl,

        [Parameter()]
        [string]$Username,

        [Parameter()]
        [string]$Password
    )

    $params = @{
        Context     = $Context
        Service     = "Core"
        Method      = "Delete"
        RelativeUrl = $RelativeUrl
        ParseJson   = $false
    }
    if ($Username) { $params.Username = $Username }
    if ($Password) { $params.Password = $Password }

    try {
        Invoke-SgDnSafeguardApi @params | Out-Null
    }
    catch {
        # Silently ignore — object may not exist
    }
}

function Test-SgDnSpsConfigured {
    <#
    .SYNOPSIS
        Returns $true if SPS connection parameters are configured.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSCustomObject]$Context
    )

    if (-not $Context) { $Context = Get-SgDnTestContext }
    return ($Context.SpsAppliance -and $Context.SpsUser -and $Context.SpsPassword)
}

function Test-SgDnIsElevated {
    <#
    .SYNOPSIS
        Returns $true if the current process is running elevated (admin).
    #>
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    else {
        return (id -u) -eq 0
    }
}

# ============================================================================
# Module Exports
# ============================================================================

Export-ModuleMember -Function @(
    # Context
    'New-SgDnTestContext'
    'Get-SgDnTestContext'

    # Cleanup
    'Register-SgDnTestCleanup'
    'Invoke-SgDnTestCleanup'

    # Tool invocation
    'Invoke-SgDnSafeguardTool'
    'Invoke-SgDnSafeguardApi'
    'Invoke-SgDnSafeguardA2aTool'
    'Invoke-SgDnSafeguardSessionsTool'
    'Build-SgDnTestProjects'

    # Assertions
    'Test-SgDnAssert'
    'Test-SgDnAssertEqual'
    'Test-SgDnAssertNotNull'
    'Test-SgDnAssertContains'
    'Test-SgDnAssertThrows'
    'Test-SgDnSkip'

    # Suite execution
    'Invoke-SgDnTestSuite'

    # Reporting
    'Write-SgDnTestReport'
    'Export-SgDnTestReport'

    # Helpers
    'Remove-SgDnSafeguardTestObject'
    'Test-SgDnSpsConfigured'
    'Test-SgDnIsElevated'
)

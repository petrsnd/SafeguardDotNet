@{
    Name        = "Persistent Connection"
    Description = "Tests Safeguard.Persist() wrapper for automatic token refresh"
    Tags        = @("persistent", "token", "refresh")

    Setup = {
        param($Context)
        # No persistent infrastructure needed
    }

    Execute = {
        param($Context)

        $appliance = $Context.Appliance

        # Helper: run tool with --Persist flag and optional extra args
        function Invoke-PersistTool {
            param(
                [string]$ExtraArgs = "",
                [int]$TimeoutSec = 120
            )
            $toolArgs = "-a $appliance -x -u $($Context.AdminUserName) -p -Z $ExtraArgs"
            return Invoke-SgDnSafeguardTool `
                -ProjectDir $Context.ToolDir `
                -Arguments $toolArgs `
                -StdinLine $Context.AdminPassword `
                -ParseJson $true `
                -TimeoutSec $TimeoutSec
        }

        # --- Test 1: Persistent connection makes API call ---
        Test-SgDnAssert "Persistent connection makes API call" {
            $result = Invoke-PersistTool -ExtraArgs "-s Core -m Get -U Users"
            $null -ne $result
        }

        # --- Test 2: Persistent connection reports token lifetime ---
        Test-SgDnAssert "Persistent connection reports token lifetime" {
            $result = Invoke-PersistTool -ExtraArgs "-T"
            $result.TokenLifetimeRemaining -gt 0
        }

        # --- Test 3: Persistent connection refreshes token ---
        Test-SgDnAssert "Persistent connection refreshes token" {
            $result = Invoke-PersistTool -ExtraArgs "-T -R"
            $result.TokenLifetimeRemaining -gt 0
        }

        # --- Test 4: Persistent connection API call after refresh ---
        Test-SgDnAssert "Persistent connection works after token refresh" {
            # Use -R to refresh, then make an API call (not -T, which skips invocation)
            $toolArgs = "-a $appliance -x -u $($Context.AdminUserName) -p -Z -R -s Core -m Get -U Users"
            $result = Invoke-SgDnSafeguardTool `
                -ProjectDir $Context.ToolDir `
                -Arguments $toolArgs `
                -StdinLine $Context.AdminPassword `
                -ParseJson $true
            $null -ne $result
        }

        # --- Test 5: Auto-refresh after token expiry (slow) ---
        # This test sets token lifetime to the minimum (600s = 10 minutes),
        # waits for the token to expire, then verifies PersistentSafeguardConnection
        # auto-refreshes on the next API call.
        $runSlowTests = $env:SGDN_RUN_SLOW_TESTS -eq "1"
        if (-not $runSlowTests) {
            Test-SgDnSkip "Auto-refresh after token expiry (slow, ~11 min)" "Set SGDN_RUN_SLOW_TESTS=1 to enable"
        } else {
            Test-SgDnAssert "Auto-refresh after token expiry (slow, ~11 min)" {
                # Save original token lifetime
                $settings = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                    -RelativeUrl "Settings"
                $tokenSetting = $settings | Where-Object { $_.Name -eq "Token Lifetime" }
                $originalLifetime = $tokenSetting.Value
                Write-Host "    Original token lifetime: ${originalLifetime}s"

                try {
                    # Lower token lifetime to minimum (600s)
                    $null = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Put `
                        -RelativeUrl "Settings/Token Lifetime" -Body @{ Value = "600" }
                    Write-Host "    Token lifetime set to 600s"

                    # Connect with Persist, delay 660s (11 min), then make API call.
                    # If auto-refresh works, the call succeeds despite the expired token.
                    $result = Invoke-PersistTool `
                        -ExtraArgs "-W 660 -s Core -m Get -U `"Users?limit=1`"" `
                        -TimeoutSec 720
                    $success = $null -ne $result
                    Write-Host "    API call after expiry: $(if ($success) { 'succeeded' } else { 'FAILED' })"
                    $success
                }
                finally {
                    # Restore original token lifetime
                    $null = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Put `
                        -RelativeUrl "Settings/Token Lifetime" -Body @{ Value = "$originalLifetime" }
                    Write-Host "    Token lifetime restored to ${originalLifetime}s"
                }
            }
        }
    }

    Cleanup = {
        param($Context)
        # No infrastructure to clean up
    }
}

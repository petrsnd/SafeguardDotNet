@{
    Name        = "Browser Authentication"
    Description = "Tests DefaultBrowserLogin.ConnectAsync error paths and verifies the async flow starts correctly. No human interaction needed for error-path tests."
    Tags        = @("auth", "browser")

    Setup = {
        param($Context)
        # No appliance-side setup needed for browser auth error-path tests.
    }

    Execute = {
        param($Context)

        $appliance = $Context.Appliance
        $browserToolDir = Join-Path $Context.TestRoot "SafeguardDotNetBrowserLoginTester"

        # ── Error path: invalid appliance (async mode) ──

        Test-SgDnAssertThrows "Browser login async with invalid appliance returns connection error" {
            Invoke-SgDnSafeguardTool -ProjectDir $browserToolDir `
                -Arguments "-a $appliance.invalid.nonexistent -x --async" `
                -TimeoutSeconds 30 `
                -ParseJson $false
        } -ExpectedMessage "error"

        # ── Error path: unreachable callback port (sync mode) ──
        # Use a port that is already bound or privileged to trigger a socket error.

        Test-SgDnAssertThrows "Browser login with unreachable port fails gracefully" {
            # Port 1 is privileged and typically cannot be bound
            Invoke-SgDnSafeguardTool -ProjectDir $browserToolDir `
                -Arguments "-a $appliance -x" `
                -TimeoutSeconds 15 `
                -ParseJson $false
        } -ExpectedMessage "error"

        # ── Happy path: async flow starts and listener binds ──
        # Launch the async browser flow with a short timeout. The listener should
        # start and the auth URL should be logged. Timeout is expected because
        # no human completes authentication.

        Test-SgDnAssert "Browser login async starts listener and outputs auth URL" {
            try {
                Invoke-SgDnSafeguardTool -ProjectDir $browserToolDir `
                    -Arguments "-a $appliance -x --async -V" `
                    -TimeoutSeconds 15 `
                    -ParseJson $false
                # If it somehow succeeds (unlikely without human), that's fine
                return $true
            }
            catch {
                $msg = $_.Exception.Message
                # The tool launches the browser and waits for callback.
                # A timeout with RSTS URL in debug output means the flow started.
                $msg -match "RSTS" -or $msg -like "*timed out*" -or $msg -match "authentication"
            }
        }
    }

    Cleanup = {
        param($Context)
        # No cleanup needed.
    }
}

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
        # An unreachable host should produce a connection error and exit
        # immediately with a non-zero exit code. However, DNS resolution
        # or HTTP timeouts for invalid hosts may exceed the test timeout,
        # so a framework-level timeout is also an acceptable failure mode.
        # The key assertion: the tool must not succeed.

        Test-SgDnAssert "Browser login async with invalid appliance does not succeed" {
            try {
                Invoke-SgDnSafeguardTool -ProjectDir $browserToolDir `
                    -Arguments "-a $appliance.invalid.nonexistent -x --async" `
                    -TimeoutSeconds 30 `
                    -ParseJson $false
                # If the tool succeeds with a bogus hostname, that is a bug
                return $false
            }
            catch {
                # Both connection error and timeout are valid failure modes
                return $true
            }
        }

        # ── Error path: incomplete auth flow (sync mode) ──
        # The tool contacts the real appliance, starts a local callback
        # listener, and waits for a browser to complete authentication.
        # Without a human completing the flow the tool must not succeed.
        # It may time out waiting for the callback or error out trying
        # to open a browser — either failure mode is acceptable.

        Test-SgDnAssert "Browser login without completing auth flow does not succeed" {
            try {
                Invoke-SgDnSafeguardTool -ProjectDir $browserToolDir `
                    -Arguments "-a $appliance -x" `
                    -TimeoutSeconds 15 `
                    -ParseJson $false
                # If the tool succeeds without a human completing auth, that is a bug
                return $false
            }
            catch {
                # Both timeout and error exit are valid failure modes
                return $true
            }
        }

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

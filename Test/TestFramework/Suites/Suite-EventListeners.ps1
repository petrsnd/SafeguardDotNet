@{
    Name        = "Event Listeners"
    Description = "Tests SignalR event listener connection, event receipt, and lifecycle"
    Tags        = @("events", "signalr", "listener")

    Setup = {
        param($Context)
        # No persistent infrastructure needed — tests manage their own listeners
    }

    Execute = {
        param($Context)

        $prefix    = $Context.TestPrefix
        $appliance = $Context.Appliance
        $toolDir   = $Context.EventToolDir

        # Helper: start an event listener process, wait for it to be ready,
        # invoke a trigger action, check output for a pattern, then shut down.
        function Start-EventListenerTest {
            param(
                [string]$ToolArgs,
                [string]$ReadyPattern,
                [scriptblock]$TriggerAction,
                [string]$ExpectPattern,
                [int]$ReadyTimeoutSec = 30,
                [int]$EventTimeoutSec = 20
            )

            $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $startInfo.FileName = "dotnet"
            $startInfo.Arguments = "run --no-build --project `"$toolDir`" -- $ToolArgs"
            $startInfo.UseShellExecute = $false
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true
            $startInfo.RedirectStandardInput = $true
            $startInfo.CreateNoWindow = $true
            $startInfo.WorkingDirectory = $toolDir

            $proc = [System.Diagnostics.Process]::new()
            $proc.StartInfo = $startInfo

            $stdout = [System.Text.StringBuilder]::new()
            $stderr = [System.Text.StringBuilder]::new()

            $stdoutEvt = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action {
                if ($null -ne $EventArgs.Data) {
                    $Event.MessageData.AppendLine($EventArgs.Data) | Out-Null
                }
            } -MessageData $stdout

            $stderrEvt = Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action {
                if ($null -ne $EventArgs.Data) {
                    $Event.MessageData.AppendLine($EventArgs.Data) | Out-Null
                }
            } -MessageData $stderr

            try {
                $proc.Start() | Out-Null
                $proc.BeginOutputReadLine()
                $proc.BeginErrorReadLine()

                # Send password via stdin (keep stdin open for shutdown signal)
                $proc.StandardInput.WriteLine($Context.AdminPassword)

                # Wait for listener to become ready
                $ready = $false
                for ($i = 0; $i -lt $ReadyTimeoutSec; $i++) {
                    Start-Sleep -Seconds 1
                    $out = $stdout.ToString()
                    if ($out -match $ReadyPattern) {
                        $ready = $true
                        break
                    }
                    if ($proc.HasExited) { break }
                }

                if (-not $ready) {
                    $msg = "Listener not ready within ${ReadyTimeoutSec}s.`nStdout: $($stdout.ToString())`nStderr: $($stderr.ToString())"
                    throw $msg
                }

                # Run the trigger action (e.g., create a user)
                $triggerResult = $null
                if ($TriggerAction) {
                    $triggerResult = & $TriggerAction
                }

                # Wait for expected pattern in output
                $matched = $false
                if ($ExpectPattern) {
                    for ($i = 0; $i -lt $EventTimeoutSec; $i++) {
                        Start-Sleep -Seconds 1
                        $out = $stdout.ToString()
                        if ($out -match $ExpectPattern) {
                            $matched = $true
                            break
                        }
                    }
                } else {
                    # No event to wait for — just checking readiness was enough
                    $matched = $ready
                }

                # Gracefully stop: send a blank line (triggers Console.ReadLine() return)
                try {
                    if (-not $proc.HasExited) {
                        $proc.StandardInput.WriteLine("")
                        $proc.WaitForExit(5000) | Out-Null
                    }
                } catch {}

                return @{ Matched = $matched; Output = $stdout.ToString(); TriggerResult = $triggerResult }
            }
            finally {
                Unregister-Event -SourceIdentifier $stdoutEvt.Name -ErrorAction SilentlyContinue
                Unregister-Event -SourceIdentifier $stderrEvt.Name -ErrorAction SilentlyContinue
                if (-not $proc.HasExited) {
                    try { $proc.Kill() } catch {}
                }
                $proc.Dispose()
            }
        }

        # --- Test 1: Standard event listener receives UserCreated event ---
        Test-SgDnAssert "Standard listener receives UserCreated event" {
            $result = Start-EventListenerTest `
                -ToolArgs "-a $appliance -x -u $($Context.AdminUserName) -E UserCreated -p" `
                -ReadyPattern "Press enter" `
                -TriggerAction {
                    $user = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
                        -RelativeUrl "Users" -Body @{
                            PrimaryAuthenticationProvider = @{ Id = -1 }
                            Name = "${prefix}_EvtUser1"
                        }
                    $user.Id
                } `
                -ExpectPattern "UserCreated"

            # Cleanup: delete the test user
            if ($result.TriggerResult) {
                try {
                    $null = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Delete `
                        -RelativeUrl "Users/$($result.TriggerResult)" -ParseJson $false
                } catch {}
            }

            $result.Matched
        }

        # --- Test 2: Persistent listener receives UserCreated event ---
        Test-SgDnAssert "Persistent listener receives UserCreated event" {
            $result = Start-EventListenerTest `
                -ToolArgs "-a $appliance -x -u $($Context.AdminUserName) -E UserCreated -P -p" `
                -ReadyPattern "Press enter" `
                -TriggerAction {
                    $user = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
                        -RelativeUrl "Users" -Body @{
                            PrimaryAuthenticationProvider = @{ Id = -1 }
                            Name = "${prefix}_EvtUser2"
                        }
                    $user.Id
                } `
                -ExpectPattern "UserCreated"

            if ($result.TriggerResult) {
                try {
                    $null = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Delete `
                        -RelativeUrl "Users/$($result.TriggerResult)" -ParseJson $false
                } catch {}
            }

            $result.Matched
        }

        # --- Test 3: Persistent listener with state callback reports Connected ---
        Test-SgDnAssert "Persistent listener reports Connected state" {
            $result = Start-EventListenerTest `
                -ToolArgs "-a $appliance -x -u $($Context.AdminUserName) -E UserCreated -P -S -p" `
                -ReadyPattern "Press enter" `
                -ExpectPattern "new event listener state"

            $result.Matched
        }
    }

    Cleanup = {
        param($Context)
        $prefix = $Context.TestPrefix
        Remove-SgDnStaleTestObject -Context $Context -Collection "Users" -Name "${prefix}_EvtUser1"
        Remove-SgDnStaleTestObject -Context $Context -Collection "Users" -Name "${prefix}_EvtUser2"
    }
}

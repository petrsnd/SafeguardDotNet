@{
    Name        = "Authorization Code Extractor"
    Description = "Local loopback unit tests for AuthorizationCodeExtractor.ListenAsync. No appliance needed — exercises TCP listener, cancellation, and error handling directly."
    Tags        = @("auth", "browser", "unit")

    Setup = {
        param($Context)

        # Locate the built BrowserLogin assembly (build must have completed first).
        $repoRoot = Split-Path -Parent $Context.TestRoot
        $browserDll = Join-Path $repoRoot "SafeguardDotNet.BrowserLogin" "bin" "Debug" "netstandard2.0" "OneIdentity.SafeguardDotNet.BrowserLogin.dll"
        $coreDll = Join-Path $repoRoot "SafeguardDotNet.BrowserLogin" "bin" "Debug" "netstandard2.0" "OneIdentity.SafeguardDotNet.dll"

        if (-not (Test-Path $browserDll)) {
            throw "BrowserLogin DLL not found at $browserDll. Run 'dotnet build' first."
        }

        # Load assemblies (order matters: core first, then browser)
        Add-Type -Path $coreDll -ErrorAction Stop
        Add-Type -Path $browserDll -ErrorAction Stop

        $Context.SuiteData['RepoRoot'] = $repoRoot
    }

    Execute = {
        param($Context)

        # Helper: pick a random high port unlikely to conflict
        function Get-RandomPort {
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
            $listener.Start()
            $port = $listener.LocalEndpoint.Port
            $listener.Stop()
            return $port
        }

        # ── Test 1: Cancellation while blocked ──
        Test-SgDnAssert "ListenAsync throws OperationCanceledException on cancellation" {
            $port = Get-RandomPort
            $cts = [System.Threading.CancellationTokenSource]::new()
            $task = [OneIdentity.SafeguardDotNet.BrowserLogin.AuthorizationCodeExtractor]::ListenAsync($port, $cts.Token)

            # Give listener a moment to start, then cancel
            Start-Sleep -Milliseconds 100
            $cts.Cancel()

            try {
                $task.GetAwaiter().GetResult()
                return $false  # Should not reach here
            }
            catch [System.OperationCanceledException] {
                return $true
            }
            catch {
                # AggregateException wrapping OperationCanceledException
                if ($_.Exception.InnerException -is [System.OperationCanceledException]) {
                    return $true
                }
                throw
            }
            finally {
                $cts.Dispose()
            }
        }

        # ── Test 2: Successful callback returns authorization code ──
        Test-SgDnAssert "ListenAsync returns auth code from valid GET request" {
            $port = Get-RandomPort
            $cts = [System.Threading.CancellationTokenSource]::new(10000)  # 10s safety timeout
            $task = [OneIdentity.SafeguardDotNet.BrowserLogin.AuthorizationCodeExtractor]::ListenAsync($port, $cts.Token)

            # Connect as client and send a valid OAuth callback
            Start-Sleep -Milliseconds 100
            $client = [System.Net.Sockets.TcpClient]::new("127.0.0.1", $port)
            try {
                $stream = $client.GetStream()
                $request = "GET /?oauth=test-auth-code-42 HTTP/1.1`r`nHost: 127.0.0.1`r`n`r`n"
                $bytes = [System.Text.Encoding]::ASCII.GetBytes($request)
                $stream.Write($bytes, 0, $bytes.Length)
                $stream.Flush()

                # Read the HTTP response from the listener
                Start-Sleep -Milliseconds 500
                $readBuf = [byte[]]::new(4096)
                if ($stream.DataAvailable) {
                    [void]$stream.Read($readBuf, 0, $readBuf.Length)
                }
            }
            finally {
                $client.Dispose()
                $cts.Dispose()
            }

            $result = $task.GetAwaiter().GetResult()
            $result -eq "test-auth-code-42"
        }

        # ── Test 3: Malformed request (no GET query) throws SafeguardDotNetException ──
        Test-SgDnAssertThrows "ListenAsync throws on malformed request without GET query" {
            $port = Get-RandomPort
            $cts = [System.Threading.CancellationTokenSource]::new(10000)
            $task = [OneIdentity.SafeguardDotNet.BrowserLogin.AuthorizationCodeExtractor]::ListenAsync($port, $cts.Token)

            Start-Sleep -Milliseconds 100
            $client = [System.Net.Sockets.TcpClient]::new("127.0.0.1", $port)
            try {
                $stream = $client.GetStream()
                $request = "POST /callback HTTP/1.1`r`nHost: 127.0.0.1`r`n`r`nbody=garbage"
                $bytes = [System.Text.Encoding]::ASCII.GetBytes($request)
                $stream.Write($bytes, 0, $bytes.Length)
                $stream.Flush()
                Start-Sleep -Milliseconds 500
            }
            finally {
                $client.Dispose()
                $cts.Dispose()
            }

            # This should throw SafeguardDotNetException ("Redirect request is not a GET query")
            $task.GetAwaiter().GetResult()
        } -ExpectedMessage "GET query"

        # ── Test 4: Port already in use throws SocketException ──
        Test-SgDnAssertThrows "ListenAsync throws when port is already bound" {
            $port = Get-RandomPort
            # Bind the port first
            $blocker = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
            $blocker.Start()
            try {
                $cts = [System.Threading.CancellationTokenSource]::new(5000)
                $task = [OneIdentity.SafeguardDotNet.BrowserLogin.AuthorizationCodeExtractor]::ListenAsync($port, $cts.Token)
                $task.GetAwaiter().GetResult()
            }
            finally {
                $blocker.Stop()
            }
        }
    }

    Cleanup = {
        param($Context)
        # No cleanup needed — all resources disposed inline.
    }
}

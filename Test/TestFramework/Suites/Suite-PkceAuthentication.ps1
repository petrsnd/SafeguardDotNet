@{
    Name        = "PKCE Authentication"
    Description = "Tests PKCE non-interactive login and error handling. If TotpSeed is provided, tests MFA (TOTP) login."
    Tags        = @("auth", "pkce", "mfa")

    Setup = { }

    Execute = {
        param($Context)

        $appliance = $Context.Appliance
        $user = $Context.AdminUserName
        $pass = $Context.AdminPassword
        $totpSeed = $Context.TotpSeed

        # ── Successful login (run first to avoid rate limiter penalties from error tests) ──

        if ($totpSeed) {
            Test-SgDnAssert "PKCE login with TOTP code succeeds" {
                $totp = python -c @"
import hmac, hashlib, struct, time, base64
secret = base64.b32decode('$totpSeed')
counter = int(time.time()) // 30
msg = struct.pack('>Q', counter)
h = hmac.new(secret, msg, hashlib.sha1).digest()
offset = h[-1] & 0x0f
code = (struct.unpack('>I', h[offset:offset+4])[0] & 0x7fffffff) % 1000000
print(f'{code:06d}')
"@
                $result = Invoke-SgDnSafeguardTool -ProjectDir $Context.PkceToolDir `
                    -Arguments "-a $appliance -x -u $user -i local -p -s $totp" `
                    -StdinLine $pass `
                    -ParseJson $false
                $result -like "*Successfully connected*"
            }
        }
        else {
            Test-SgDnAssert "PKCE login succeeds" {
                $result = Invoke-SgDnSafeguardTool -ProjectDir $Context.PkceToolDir `
                    -Arguments "-a $appliance -x -u $user -i local -p" `
                    -StdinLine $pass `
                    -ParseJson $false
                $result -like "*Successfully connected*"
            }
        }

        # ── Error handling (standard mode only to avoid rSTS rate limiting) ──

        if (-not $totpSeed) {
            Test-SgDnAssert "PKCE login with wrong password returns error" {
                try {
                    Invoke-SgDnSafeguardTool -ProjectDir $Context.PkceToolDir `
                        -Arguments "-a $appliance -x -u $user -i local -p" `
                        -StdinLine "WRONGPASSWORD" `
                        -ParseJson $false
                    throw "Expected an exception but none was thrown"
                }
                catch {
                    $msg = $_.Exception.Message
                    $msg -like "*Invalid password*" -or $msg -like "*Access denied*"
                }
            }

            Test-SgDnAssert "PKCE login with unknown user returns error" {
                try {
                    Invoke-SgDnSafeguardTool -ProjectDir $Context.PkceToolDir `
                        -Arguments "-a $appliance -x -u NoSuchUser_ZZZZZ -i local -p" `
                        -StdinLine "anypassword" `
                        -ParseJson $false
                    throw "Expected an exception but none was thrown"
                }
                catch {
                    $msg = $_.Exception.Message
                    $msg -like "*User is unknown*" -or $msg -like "*Access denied*"
                }
            }

            Test-SgDnAssertThrows "PKCE login with unknown provider returns error" {
                Invoke-SgDnSafeguardTool -ProjectDir $Context.PkceToolDir `
                    -Arguments "-a $appliance -x -u $user -i nonexistent_provider -p" `
                    -StdinLine $pass `
                    -ParseJson $false
            } -ExpectedMessage "Unable to find scope"
        }
    }

    Cleanup = {
        param($Context)
        # No test objects to clean up — suite uses pre-existing users.
    }
}

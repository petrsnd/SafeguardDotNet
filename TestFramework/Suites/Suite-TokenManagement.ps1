@{
    Name        = "Token Management"
    Description = "Tests access token retrieval, refresh, lifetime bounds, and logout"
    Tags        = @("auth", "token")

    Setup = {
        param($Context)
        # No setup needed - uses bootstrap admin credentials.
    }

    Execute = {
        param($Context)

        Test-SgJAssert "Token lifetime is positive after fresh connection" {
            $result = Invoke-SgJTokenCommand -Context $Context -Command TokenLifetime
            $null -ne $result.TokenLifetimeRemaining -and $result.TokenLifetimeRemaining -gt 0
        }

        Test-SgJAssert "Token lifetime is within expected bounds (1-1440 minutes)" {
            $result = Invoke-SgJTokenCommand -Context $Context -Command TokenLifetime
            $result.TokenLifetimeRemaining -ge 1 -and $result.TokenLifetimeRemaining -le 1440
        }

        Test-SgJAssert "GetToken returns a non-empty access token" {
            $result = Invoke-SgJTokenCommand -Context $Context -Command GetToken
            $null -ne $result.AccessToken -and $result.AccessToken.Length -gt 0
        }

        Test-SgJAssert "Access token can be used for subsequent API call" {
            $tokenResult = Invoke-SgJTokenCommand -Context $Context -Command GetToken
            $token = $tokenResult.AccessToken

            $meResult = Invoke-SgJSafeguardApi -Context $Context `
                -Service Core -Method Get -RelativeUrl "Me" `
                -AccessToken $token
            $null -ne $meResult -and $meResult.Name -eq $Context.AdminUserName.ToLower()
        }

        Test-SgJAssert "RefreshAccessToken succeeds and lifetime is positive" {
            $result = Invoke-SgJTokenCommand -Context $Context -Command RefreshToken
            $result.TokenLifetimeRemaining -gt 0
        }

        Test-SgJAssert "Refreshed token lifetime is within expected bounds" {
            $result = Invoke-SgJTokenCommand -Context $Context -Command RefreshToken
            $result.TokenLifetimeRemaining -ge 1 -and $result.TokenLifetimeRemaining -le 1440
        }

        Test-SgJAssert "LogOut returns access token and confirms logged out" {
            $result = Invoke-SgJTokenCommand -Context $Context -Command Logout
            $result.LoggedOut -eq $true -and $result.AccessToken.Length -gt 0
        }

        Test-SgJAssert "Logged-out token is rejected by the API" {
            $logoutResult = Invoke-SgJTokenCommand -Context $Context -Command Logout
            $token = $logoutResult.AccessToken

            # Try to use the invalidated token - should be rejected
            $rejected = $false
            try {
                $uri = "https://$($Context.Appliance)/service/core/v4/Me"
                $headers = @{ Authorization = "Bearer $token" }
                $null = Invoke-RestMethod -Uri $uri -Headers $headers -SkipCertificateCheck -ErrorAction Stop
            }
            catch {
                $rejected = $true
            }
            $rejected
        }
    }

    Cleanup = {
        param($Context)
        # Nothing to clean up.
    }
}

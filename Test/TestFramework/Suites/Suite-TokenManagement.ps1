@{
    Name        = "Token Management"
    Description = "Tests GetAccessTokenLifetimeRemaining, RefreshAccessToken, and LogOut via SafeguardDotNet"
    Tags        = @("token", "auth", "core")

    Setup = {
        param($Context)
        # No setup needed — all tests use the bootstrap Admin account directly.
    }

    Execute = {
        param($Context)

        # --- Token lifetime is positive after connect ---
        Test-SgDnAssert "Token lifetime is positive after connect" {
            $result = Invoke-SgDnTokenCommand -Context $Context -Command TokenLifetime
            $result.TokenLifetimeRemaining -gt 0
        }

        # --- Token lifetime is within expected bounds ---
        Test-SgDnAssert "Token lifetime is within expected bounds (1-1440 minutes)" {
            $result = Invoke-SgDnTokenCommand -Context $Context -Command TokenLifetime
            $result.TokenLifetimeRemaining -ge 1 -and $result.TokenLifetimeRemaining -le 1440
        }

        # --- Refresh token returns positive lifetime ---
        Test-SgDnAssert "RefreshAccessToken succeeds and lifetime is positive" {
            $result = Invoke-SgDnTokenCommand -Context $Context -Command RefreshToken
            $result.TokenLifetimeRemaining -gt 0
        }

        # --- Refresh token returns lifetime within bounds ---
        Test-SgDnAssert "Refreshed token lifetime is within expected bounds" {
            $result = Invoke-SgDnTokenCommand -Context $Context -Command RefreshToken
            $result.TokenLifetimeRemaining -ge 1 -and $result.TokenLifetimeRemaining -le 1440
        }

        # --- LogOut returns a token and confirms logout ---
        Test-SgDnAssert "LogOut returns access token and confirms logged out" {
            $result = Invoke-SgDnTokenCommand -Context $Context -Command Logout
            $result.LoggedOut -eq $true -and $result.AccessToken.Length -gt 0
        }

        # --- LogOut invalidates the token (cannot reuse it) ---
        Test-SgDnAssert "Logged-out token is rejected by the API" {
            $logoutResult = Invoke-SgDnTokenCommand -Context $Context -Command Logout
            $token = $logoutResult.AccessToken

            # Try to use the invalidated token via access token auth
            # The tool doesn't support access token auth directly, so we make a raw
            # HTTP call with the invalidated bearer token.
            $rejected = $false
            try {
                $uri = "https://$($Context.Appliance)/service/core/v4/Me"
                $headers = @{ Authorization = "Bearer $token" }
                # Use -SkipCertificateCheck for self-signed cert on test appliance
                $null = Invoke-RestMethod -Uri $uri -Headers $headers -SkipCertificateCheck -ErrorAction Stop
            }
            catch {
                # 401 Unauthorized expected after logout
                $rejected = $true
            }
            $rejected
        }
    }

    Cleanup = {
        param($Context)
        # No cleanup needed — no objects created.
    }
}

@{
    Name        = "Access Token Authentication"
    Description = "Tests connecting to Safeguard using a pre-obtained access token via Safeguard.Connect(address, token)"
    Tags        = @("token", "auth", "core")

    Setup = {
        param($Context)

        # Obtain a valid access token via password auth without invalidating it.
        $tokenResult = Invoke-SgDnTokenCommand -Context $Context -Command GetToken
        $Context.SuiteData["AccessToken"] = $tokenResult.AccessToken
    }

    Execute = {
        param($Context)

        $token = $Context.SuiteData["AccessToken"]

        # --- Connect with access token and call API ---
        Test-SgDnAssert "Access token auth: GET Me returns identity" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -AccessToken $token
            $null -ne $result.Name
        }

        # --- Verify identity matches the bootstrap admin ---
        Test-SgDnAssert "Access token auth: identity matches original user" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -AccessToken $token
            $result.Name -eq "admin"
        }

        # --- Access token auth can list objects ---
        Test-SgDnAssert "Access token auth: can list Users" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Users" -AccessToken $token
            $items = @($result)
            $items.Count -ge 1
        }

        # --- Full response works with access token auth ---
        Test-SgDnAssert "Access token auth: Full response returns StatusCode 200" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -AccessToken $token -Full
            $result.StatusCode -eq 200
        }

        # --- Invalid access token is rejected ---
        Test-SgDnAssert "Invalid access token is rejected" {
            $rejected = $false
            try {
                Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                    -RelativeUrl "Me" -AccessToken "not-a-valid-token"
            }
            catch {
                $rejected = $true
            }
            $rejected
        }
    }

    Cleanup = {
        param($Context)
        # No objects created — nothing to clean up.
        # The access token will expire naturally.
    }
}

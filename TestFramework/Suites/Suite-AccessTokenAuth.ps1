@{
    Name        = "Access Token Authentication"
    Description = "Tests connecting to Safeguard using a pre-obtained access token via Safeguard.connect(address, token)"
    Tags        = @("token", "auth", "core")

    Setup = {
        param($Context)

        # Obtain a valid access token via password auth
        $tokenResult = Invoke-SgJTokenCommand -Context $Context -Command GetToken
        $Context.SuiteData["AccessToken"] = $tokenResult.AccessToken
    }

    Execute = {
        param($Context)

        $token = $Context.SuiteData["AccessToken"]

        # --- Connect with access token and call API ---
        Test-SgJAssert "Access token auth: GET Me returns identity" {
            $result = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -AccessToken $token
            $null -ne $result.Name
        }

        # --- Verify identity matches the bootstrap admin ---
        Test-SgJAssert "Access token auth: identity matches original user" {
            $result = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -AccessToken $token
            $result.Name -eq $Context.AdminUserName.ToLower()
        }

        # --- Access token auth can list objects ---
        Test-SgJAssert "Access token auth: can list Users" {
            $result = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Users" -AccessToken $token
            $items = @($result)
            $items.Count -ge 1
        }

        # --- Full response works with access token auth ---
        Test-SgJAssert "Access token auth: Full response returns StatusCode 200" {
            $result = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -AccessToken $token -Full
            $result.StatusCode -eq 200
        }

        # --- Invalid access token is rejected ---
        Test-SgJAssertThrows "Invalid access token is rejected" {
            Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -AccessToken "not-a-valid-token"
        }
    }

    Cleanup = {
        param($Context)
        # No objects created - the access token will expire naturally.
    }
}

@{
    Name        = "PKCE Authentication"
    Description = "Tests PKCE (Proof Key for Code Exchange) authentication in isolation"
    Tags        = @("auth", "pkce")

    Setup = {
        param($Context)
        # No setup needed — uses bootstrap admin credentials via PKCE
    }

    Execute = {
        param($Context)

        Test-SgJAssert "PKCE bootstrap admin can call Me endpoint" {
            $result = Invoke-SgJSafeguardApi -Context $Context `
                -Service Core -Method Get -RelativeUrl "Me" -Pkce
            $null -ne $result -and $result.Name -eq $Context.AdminUserName.ToLower()
        }

        Test-SgJAssert "PKCE token lifetime is positive" {
            $result = Invoke-SgJTokenCommand -Context $Context -Command TokenLifetime -Pkce
            $result.TokenLifetimeRemaining -gt 0
        }

        Test-SgJAssert "PKCE GetToken returns a non-empty access token" {
            $result = Invoke-SgJTokenCommand -Context $Context -Command GetToken -Pkce
            $null -ne $result.AccessToken -and $result.AccessToken.Length -gt 0
        }

        Test-SgJAssert "PKCE access token can be used for subsequent API call" {
            $tokenResult = Invoke-SgJTokenCommand -Context $Context -Command GetToken -Pkce
            $meResult = Invoke-SgJSafeguardApi -Context $Context `
                -Service Core -Method Get -RelativeUrl "Me" `
                -AccessToken $tokenResult.AccessToken
            $null -ne $meResult -and $null -ne $meResult.Id
        }

        Test-SgJAssert "PKCE can read appliance settings" {
            $result = Invoke-SgJSafeguardApi -Context $Context `
                -Service Core -Method Get -RelativeUrl "Settings" -Pkce
            $result -is [array] -and $result.Count -gt 0
        }
    }

    Cleanup = {
        param($Context)
        # No cleanup needed.
    }
}

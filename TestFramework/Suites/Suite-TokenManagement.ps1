@{
    Name        = "Token Management"
    Description = "Tests access token retrieval and token lifetime operations"
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

        Test-SgJAssert "GetToken returns a non-empty access token" {
            $result = Invoke-SgJTokenCommand -Context $Context -Command GetToken
            $null -ne $result.AccessToken -and $result.AccessToken.Length -gt 0
        }

        Test-SgJAssert "Access token can be used for subsequent API call" {
            # Get a token
            $tokenResult = Invoke-SgJTokenCommand -Context $Context -Command GetToken
            $token = $tokenResult.AccessToken

            # Use it to call Me
            $meResult = Invoke-SgJSafeguardApi -Context $Context `
                -Service Core -Method Get -RelativeUrl "Me" `
                -AccessToken $token
            $null -ne $meResult -and $null -ne $meResult.Id
        }
    }

    Cleanup = {
        param($Context)
        # Nothing to clean up.
    }
}

@{
    Name        = "Anonymous Access"
    Description = "Tests unauthenticated access to the Notification service"
    Tags        = @("core", "anonymous")

    Setup = {
        param($Context)
        # No setup needed - anonymous endpoints require no credentials or test objects.
    }

    Execute = {
        param($Context)

        Test-SgJAssert "Anonymous Notification Status endpoint is reachable" {
            $result = Invoke-SgJSafeguardApi -Context $Context `
                -Service Notification -Method Get -RelativeUrl "Status" -Anonymous
            $null -ne $result
        }

        Test-SgJAssert "Anonymous status response contains ApplianceCurrentState" {
            $result = Invoke-SgJSafeguardApi -Context $Context `
                -Service Notification -Method Get -RelativeUrl "Status" -Anonymous
            $null -ne $result.ApplianceCurrentState -and $result.ApplianceCurrentState.Length -gt 0
        }

        Test-SgJAssert "Anonymous status ApplianceCurrentState is Online" {
            $result = Invoke-SgJSafeguardApi -Context $Context `
                -Service Notification -Method Get -RelativeUrl "Status" -Anonymous
            $result.ApplianceCurrentState -eq "Online"
        }
    }

    Cleanup = {
        param($Context)
        # Nothing to clean up.
    }
}

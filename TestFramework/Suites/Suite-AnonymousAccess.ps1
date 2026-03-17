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

        Test-SgJAssert "Anonymous response contains appliance state" {
            $result = Invoke-SgJSafeguardApi -Context $Context `
                -Service Notification -Method Get -RelativeUrl "Status" -Anonymous -ParseJson $false
            $null -ne $result -and $result.Length -gt 0
        }
    }

    Cleanup = {
        param($Context)
        # Nothing to clean up.
    }
}

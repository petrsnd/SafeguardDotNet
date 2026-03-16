@{
    Name        = "Anonymous Access"
    Description = "Tests unauthenticated access to the Notification service"
    Tags        = @("core", "anonymous")

    Setup = {
        param($Context)
        # No setup needed — anonymous endpoints require no credentials or test objects.
    }

    Execute = {
        param($Context)

        Test-SgDnAssert "Anonymous Notification Status endpoint is reachable" {
            $result = Invoke-SgDnSafeguardApi -Context $Context `
                -Service Notification -Method Get -RelativeUrl "Status" -Anonymous
            $null -ne $result
        }
    }

    Cleanup = {
        param($Context)
        # Nothing to clean up.
    }
}

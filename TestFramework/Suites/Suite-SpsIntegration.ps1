@{
    Name        = "SPS Integration"
    Description = "Tests Safeguard for Privileged Sessions API connectivity"
    Tags        = @("sps")

    Setup = {
        param($Context)
        if (-not (Test-SgJSpsConfigured -Context $Context)) {
            $Context.SuiteData["Skipped"] = $true
        }
    }

    Execute = {
        param($Context)

        if ($Context.SuiteData["Skipped"]) {
            Test-SgJSkip "SPS authentication" "SPS appliance not configured"
            Test-SgJSkip "SPS firmware slots query" "SPS appliance not configured"
            Test-SgJSkip "SPS full response has status 200" "SPS appliance not configured"
            return
        }

        Test-SgJAssert "SPS authentication" {
            $result = Invoke-SgJSafeguardSessions -Context $Context `
                -Method Get -RelativeUrl "configuration/management/email"
            $null -ne $result
        }

        Test-SgJAssert "SPS firmware slots query" {
            $result = Invoke-SgJSafeguardSessions -Context $Context `
                -Method Get -RelativeUrl "firmware/slots"
            $null -ne $result
        }

        Test-SgJAssert "SPS full response has status 200" {
            $result = Invoke-SgJSafeguardSessions -Context $Context `
                -Method Get -RelativeUrl "firmware/slots" -Full
            $result.StatusCode -eq 200
        }
    }

    Cleanup = {
        param($Context)
        # No objects created.
    }
}

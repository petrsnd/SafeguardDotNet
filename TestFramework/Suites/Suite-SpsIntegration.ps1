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
            Test-SgJSkip "SPS authentication and email config query" "SPS appliance not configured"
            Test-SgJSkip "SPS firmware slots query returns body key" "SPS appliance not configured"
            Test-SgJSkip "SPS full response has status 200" "SPS appliance not configured"
            Test-SgJSkip "Invalid SPS endpoint returns error" "SPS appliance not configured"
            return
        }

        Test-SgJAssert "SPS authentication and email config query" {
            $result = Invoke-SgJSafeguardSessions -Context $Context `
                -Method Get -RelativeUrl "configuration/management/email"
            $null -ne $result
        }

        Test-SgJAssert "SPS firmware slots query returns body key" {
            $result = Invoke-SgJSafeguardSessions -Context $Context `
                -Method Get -RelativeUrl "firmware/slots"
            $null -ne $result -and $null -ne $result.body
        }

        Test-SgJAssert "SPS full response has status 200" {
            $result = Invoke-SgJSafeguardSessions -Context $Context `
                -Method Get -RelativeUrl "firmware/slots" -Full
            $result.StatusCode -eq 200
        }

        Test-SgJAssert "Invalid SPS endpoint returns error" {
            $rejected = $false
            try {
                Invoke-SgJSafeguardSessions -Context $Context `
                    -Method Get -RelativeUrl "nonexistent/endpoint/that/should/fail"
            }
            catch {
                $rejected = $true
            }
            $rejected
        }
    }

    Cleanup = {
        param($Context)
        # No objects created.
    }
}

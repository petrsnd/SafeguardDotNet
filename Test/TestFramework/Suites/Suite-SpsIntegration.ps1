@{
    Name        = "SPS Integration"
    Description = "Tests Safeguard for Privileged Sessions API connectivity"
    Tags        = @("sps")

    Setup = {
        param($Context)
        if (-not (Test-SgDnSpsConfigured -Context $Context)) {
            $Context.SuiteData["Skipped"] = $true
        }
    }

    Execute = {
        param($Context)

        if ($Context.SuiteData["Skipped"]) {
            Test-SgDnSkip "SPS firmware slots query" "SPS appliance not configured"
            return
        }

        Test-SgDnAssert "Can query SPS firmware slots" {
            $result = Invoke-SgDnSafeguardSessions -Context $Context `
                -Method Get -RelativeUrl "firmware/slots"
            $null -ne $result
        }
    }

    Cleanup = {
        param($Context)
        # No objects created.
    }
}

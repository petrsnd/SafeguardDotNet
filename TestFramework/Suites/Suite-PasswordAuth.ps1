@{
    Name        = "Password Authentication"
    Description = "Tests password-based authentication and basic admin API access"
    Tags        = @("auth", "core")

    Setup = {
        param($Context)

        $prefix = $Context.TestPrefix
        $testUser = "${prefix}_PwdAuthUser"
        $testPassword = "Test1234Password!@#"

        # Pre-cleanup: remove stale objects from previous failed runs
        Remove-SgJStaleTestObject -Context $Context -Collection "Users" -Name $testUser

        # Create a test user with admin roles
        $user = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "Users" -Body @{
                PrimaryAuthenticationProvider = @{ Id = -1 }
                Name = $testUser
                AdminRoles = @('Auditor')
            }
        $Context.SuiteData["UserId"] = $user.Id
        $Context.SuiteData["UserName"] = $testUser
        $Context.SuiteData["UserPassword"] = $testPassword

        # Register cleanup IMMEDIATELY after creation
        Register-SgJTestCleanup -Description "Delete password auth test user" -Action {
            param($Ctx)
            Remove-SgJSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Users/$($Ctx.SuiteData['UserId'])"
        }

        # Set password
        Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Put `
            -RelativeUrl "Users/$($user.Id)/Password" -Body "'$testPassword'" -ParseJson $false
    }

    Execute = {
        param($Context)

        Test-SgJAssert "Bootstrap admin can connect and call Me endpoint" {
            $result = Invoke-SgJSafeguardApi -Context $Context `
                -Service Core -Method Get -RelativeUrl "Me"
            $null -ne $result -and $result.Name -eq $Context.AdminUserName.ToLower()
        }

        Test-SgJAssert "Test user can authenticate with password" {
            $result = Invoke-SgJSafeguardApi -Context $Context `
                -Service Core -Method Get -RelativeUrl "Me" `
                -Username $Context.SuiteData["UserName"] `
                -Password $Context.SuiteData["UserPassword"]
            $result.Name -eq $Context.SuiteData["UserName"]
        }

        Test-SgJAssert "Test user Id matches created user" {
            $result = Invoke-SgJSafeguardApi -Context $Context `
                -Service Core -Method Get -RelativeUrl "Me" `
                -Username $Context.SuiteData["UserName"] `
                -Password $Context.SuiteData["UserPassword"]
            $result.Id -eq $Context.SuiteData["UserId"]
        }

        Test-SgJAssert "Token lifetime is positive after authentication" {
            $result = Invoke-SgJTokenCommand -Context $Context -Command TokenLifetime
            $result.TokenLifetimeRemaining -gt 0
        }

        Test-SgJAssert "Wrong password is rejected" {
            $rejected = $false
            try {
                Invoke-SgJSafeguardApi -Context $Context `
                    -Service Core -Method Get -RelativeUrl "Me" `
                    -Username $Context.SuiteData["UserName"] `
                    -Password "CompletelyWrongPassword!99"
            }
            catch {
                $rejected = $true
            }
            $rejected
        }
    }

    Cleanup = {
        param($Context)
        # Registered cleanup handles user deletion.
    }
}

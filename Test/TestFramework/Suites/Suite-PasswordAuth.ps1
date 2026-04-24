@{
    Name        = "Password Authentication"
    Description = "Tests password-based authentication and basic admin API access"
    Tags        = @("auth", "core")

    Setup = {
        param($Context)

        $prefix = $Context.TestPrefix
        $testUser = "${prefix}_PwdAuthUser"
        $testPassword = "2309aseflkasdlf209349qauerA"

        # Pre-cleanup: remove stale objects from previous failed runs
        Write-Host "    Removing stale objects from previous runs..." -ForegroundColor DarkGray
        Remove-SgDnStaleTestObject -Context $Context -Collection "Users" -Name $testUser

        # Create a test user with admin roles
        Write-Host "    Creating test user '$testUser'..." -ForegroundColor DarkGray
        $user = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "Users" -Body @{
                PrimaryAuthenticationProvider = @{ Id = -1 }
                Name = $testUser
                AdminRoles = @('Auditor')
            }
        $Context.SuiteData["UserId"] = $user.Id
        $Context.SuiteData["UserName"] = $testUser
        $Context.SuiteData["UserPassword"] = $testPassword

        # Register cleanup IMMEDIATELY after creation
        Register-SgDnTestCleanup -Description "Delete password auth test user" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Users/$($Ctx.SuiteData['UserId'])"
        }

        # Set password
        Write-Host "    Setting user password..." -ForegroundColor DarkGray
        Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Put `
            -RelativeUrl "Users/$($user.Id)/Password" -Body "'$testPassword'" -ParseJson $false
    }

    Execute = {
        param($Context)

        Test-SgDnAssert "Bootstrap admin can connect and call Me endpoint" {
            $result = Invoke-SgDnSafeguardApi -Context $Context `
                -Service Core -Method Get -RelativeUrl "Me"
            $null -ne $result -and $null -ne $result.Id
        }

        Test-SgDnAssert "Test user can authenticate with password" {
            $result = Invoke-SgDnSafeguardApi -Context $Context `
                -Service Core -Method Get -RelativeUrl "Me" `
                -Username $Context.SuiteData["UserName"] `
                -Password $Context.SuiteData["UserPassword"]
            $result.Name -eq $Context.SuiteData["UserName"]
        }
    }

    Cleanup = {
        param($Context)
        # Registered cleanup handles user deletion.
    }
}

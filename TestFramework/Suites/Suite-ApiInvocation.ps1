@{
    Name        = "API Invocation Patterns"
    Description = "Tests HTTP methods, query parameters, PUT updates, InvokeMethodFull, and custom headers"
    Tags        = @("api", "core")

    Setup = {
        param($Context)

        $prefix = $Context.TestPrefix
        $adminUser = "${prefix}_ApiAdmin"
        $adminPassword = "Test1234ApiAdmin!@#"

        # Pre-cleanup
        Remove-SgJStaleTestObject -Context $Context -Collection "AssetAccounts" -Name "${prefix}_ApiAccount"
        Remove-SgJStaleTestObject -Context $Context -Collection "Assets" -Name "${prefix}_ApiAsset"
        Remove-SgJStaleTestObject -Context $Context -Collection "Users" -Name "${prefix}_ApiDeleteMe"
        Remove-SgJStaleTestObject -Context $Context -Collection "Users" -Name "${prefix}_ApiFullPost"
        Remove-SgJStaleTestObject -Context $Context -Collection "Users" -Name "${prefix}_ApiFullDel"
        Remove-SgJStaleTestObject -Context $Context -Collection "Users" -Name $adminUser

        # Create admin user for privileged operations
        $admin = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "Users" -Body @{
                PrimaryAuthenticationProvider = @{ Id = -1 }
                Name = $adminUser
                AdminRoles = @('GlobalAdmin','Auditor','AssetAdmin','ApplianceAdmin','PolicyAdmin','UserAdmin','HelpdeskAdmin','OperationsAdmin')
            }
        $Context.SuiteData["AdminUserId"] = $admin.Id
        $Context.SuiteData["AdminUser"] = $adminUser
        $Context.SuiteData["AdminPassword"] = $adminPassword
        Register-SgJTestCleanup -Description "Delete API admin user" -Action {
            param($Ctx)
            Remove-SgJSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Users/$($Ctx.SuiteData['AdminUserId'])"
        }
        Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Put `
            -RelativeUrl "Users/$($admin.Id)/Password" -Body "'$adminPassword'" -ParseJson $false

        # Create an asset for testing non-User endpoints
        $asset = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "Assets" `
            -Username $adminUser -Password $adminPassword `
            -Body @{
                Name = "${prefix}_ApiAsset"
                Description = "test asset for API invocation"
                PlatformId = 188
                AssetPartitionId = -1
                NetworkAddress = "fake.api.address.com"
            }
        $Context.SuiteData["AssetId"] = $asset.Id
        Register-SgJTestCleanup -Description "Delete test asset" -Action {
            param($Ctx)
            Remove-SgJSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Assets/$($Ctx.SuiteData['AssetId'])" `
                -Username $Ctx.SuiteData['AdminUser'] -Password $Ctx.SuiteData['AdminPassword']
        }
    }

    Execute = {
        param($Context)

        $adminUser = $Context.SuiteData["AdminUser"]
        $adminPassword = $Context.SuiteData["AdminPassword"]
        $prefix = $Context.TestPrefix

        # --- GET returns data ---
        Test-SgJAssert "GET Users returns a list" {
            $result = Invoke-SgJSafeguardApi -Context $Context `
                -Service Core -Method Get -RelativeUrl "Users"
            $items = @($result)
            $items.Count -ge 1
        }

        # --- GET with query filter ---
        Test-SgJAssert "GET with filter returns matching objects only" {
            $result = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Users?filter=Name eq '$adminUser'"
            $items = @($result)
            $items.Count -eq 1 -and $items[0].Name -eq $adminUser
        }

        # --- GET with contains filter ---
        Test-SgJAssert "GET with contains filter finds test objects" {
            $result = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Users?filter=Name contains '${prefix}'"
            $items = @($result)
            $items.Count -ge 1
        }

        # --- GET with ordering ---
        Test-SgJAssert "GET with orderby returns ordered results" {
            $result = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Users?orderby=Name"
            $items = @($result)
            if ($items.Count -lt 2) { $false; return }
            $ordered = $true
            for ($i = 1; $i -lt $items.Count; $i++) {
                if ($items[$i].Name -lt $items[$i - 1].Name) {
                    $ordered = $false
                    break
                }
            }
            $ordered
        }

        # --- DELETE removes an object ---
        Test-SgJAssert "DELETE removes an object" {
            $tempUser = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Post `
                -RelativeUrl "Users" -Body @{
                    PrimaryAuthenticationProvider = @{ Id = -1 }
                    Name = "${prefix}_ApiDeleteMe"
                }
            $tempId = $tempUser.Id

            Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Delete `
                -RelativeUrl "Users/$tempId" -ParseJson $false

            $found = $true
            try {
                Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                    -RelativeUrl "Users/$tempId"
            }
            catch {
                $found = $false
            }
            -not $found
        }

        # --- PUT update ---
        Test-SgJAssert "PUT updates an existing object" {
            $assetId = $Context.SuiteData["AssetId"]
            $newDesc = "updated by ApiInvocation test"

            $before = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Assets/$assetId" `
                -Username $adminUser -Password $adminPassword

            $updated = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Put `
                -RelativeUrl "Assets/$assetId" `
                -Username $adminUser -Password $adminPassword `
                -Body @{
                    Id = $assetId
                    Name = $before.Name
                    Description = $newDesc
                    PlatformId = $before.PlatformId
                    AssetPartitionId = $before.AssetPartitionId
                    NetworkAddress = $before.NetworkAddress
                }

            $updated.Description -eq $newDesc
        }

        # --- InvokeMethodFull: GET returns 200 ---
        Test-SgJAssert "Full response GET returns StatusCode 200" {
            $result = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -Full
            $result.StatusCode -eq 200
        }

        # --- InvokeMethodFull: response contains Body ---
        Test-SgJAssert "Full response Body contains user identity" {
            $result = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -Full
            $body = $result.Body
            if ($body -is [string]) { $body = $body | ConvertFrom-Json }
            $null -ne $body.Name
        }

        # --- InvokeMethodFull: response contains Headers ---
        Test-SgJAssert "Full response contains Headers" {
            $result = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -Full
            $null -ne $result.Headers -and $result.Headers.Count -gt 0
        }

        # --- InvokeMethodFull: POST returns 201 ---
        Test-SgJAssert "Full response POST returns StatusCode 201" {
            Remove-SgJStaleTestObject -Context $Context -Collection "Users" -Name "${prefix}_ApiFullPost"
            $result = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Post `
                -RelativeUrl "Users" -Full -Body @{
                    PrimaryAuthenticationProvider = @{ Id = -1 }
                    Name = "${prefix}_ApiFullPost"
                }
            try {
                $result.StatusCode -eq 201
            }
            finally {
                $body = $result.Body
                if ($body -is [string]) { $body = $body | ConvertFrom-Json }
                if ($body.Id) {
                    try {
                        Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Delete `
                            -RelativeUrl "Users/$($body.Id)" -ParseJson $false
                    } catch {}
                }
            }
        }

        # --- InvokeMethodFull: DELETE returns 204 ---
        Test-SgJAssert "Full response DELETE returns StatusCode 204" {
            Remove-SgJStaleTestObject -Context $Context -Collection "Users" -Name "${prefix}_ApiFullDel"
            $tempUser = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Post `
                -RelativeUrl "Users" -Body @{
                    PrimaryAuthenticationProvider = @{ Id = -1 }
                    Name = "${prefix}_ApiFullDel"
                }
            $deleteResult = Invoke-SgJSafeguardApi -Context $Context -Service Core -Method Delete `
                -RelativeUrl "Users/$($tempUser.Id)" -Full
            $deleteResult.StatusCode -eq 204
        }

        # --- GET against Notification service (anonymous) ---
        Test-SgJAssert "GET against Notification service (anonymous) works" {
            $result = Invoke-SgJSafeguardApi -Context $Context -Service Notification -Method Get `
                -RelativeUrl "Status" -Anonymous -ParseJson $false
            $null -ne $result -and $result.Length -gt 0
        }
    }

    Cleanup = {
        param($Context)
        # Registered cleanup handles everything.
    }
}

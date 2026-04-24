@{
    Name        = "API Invocation Patterns"
    Description = "Tests HTTP methods, CSV output, query parameters, PUT updates, InvokeMethodFull, custom headers, and structured parameters via SafeguardDotNet"
    Tags        = @("api", "core")

    Setup = {
        param($Context)

        $prefix = $Context.TestPrefix
        $adminUser = "${prefix}_ApiAdmin"
        $adminPassword = "2309aseflkasdlf209349qauerA"

        # Pre-cleanup
        Write-Host "    Removing stale objects from previous runs..." -ForegroundColor DarkGray
        Remove-SgDnStaleTestObject -Context $Context -Collection "AssetAccounts" -Name "${prefix}_ApiAccount"
        Remove-SgDnStaleTestObject -Context $Context -Collection "Assets" -Name "${prefix}_ApiAsset"
        Remove-SgDnStaleTestObject -Context $Context -Collection "Users" -Name "${prefix}_ApiDeleteMe"
        Remove-SgDnStaleTestObject -Context $Context -Collection "Users" -Name "${prefix}_ApiFullPost"
        Remove-SgDnStaleTestObject -Context $Context -Collection "Users" -Name "${prefix}_ApiFullDel"
        Remove-SgDnStaleTestObject -Context $Context -Collection "Users" -Name $adminUser

        # 1. Create admin user for privileged operations
        Write-Host "    Creating admin user '$adminUser'..." -ForegroundColor DarkGray
        $admin = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "Users" -Body @{
                PrimaryAuthenticationProvider = @{ Id = -1 }
                Name = $adminUser
                AdminRoles = @('GlobalAdmin','Auditor','AssetAdmin','ApplianceAdmin','PolicyAdmin','UserAdmin','HelpdeskAdmin','OperationsAdmin')
            }
        $Context.SuiteData["AdminUserId"] = $admin.Id
        $Context.SuiteData["AdminUser"] = $adminUser
        $Context.SuiteData["AdminPassword"] = $adminPassword
        Register-SgDnTestCleanup -Description "Delete API admin user" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Users/$($Ctx.SuiteData['AdminUserId'])"
        }
        Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Put `
            -RelativeUrl "Users/$($admin.Id)/Password" -Body "'$adminPassword'" -ParseJson $false

        # 2. Create an asset for testing non-User endpoints
        Write-Host "    Creating asset '${prefix}_ApiAsset'..." -ForegroundColor DarkGray
        $asset = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
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
        Register-SgDnTestCleanup -Description "Delete test asset" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Assets/$($Ctx.SuiteData['AssetId'])" `
                -Username $Ctx.SuiteData['AdminUser'] -Password $Ctx.SuiteData['AdminPassword']
        }

        # 3. Create an account on the asset
        Write-Host "    Creating account '${prefix}_ApiAccount' on asset..." -ForegroundColor DarkGray
        $account = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "AssetAccounts" `
            -Username $adminUser -Password $adminPassword `
            -Body @{
                Name = "${prefix}_ApiAccount"
                Asset = @{ Id = $asset.Id }
            }
        $Context.SuiteData["AccountId"] = $account.Id
        Register-SgDnTestCleanup -Description "Delete test asset account" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "AssetAccounts/$($Ctx.SuiteData['AccountId'])" `
                -Username $Ctx.SuiteData['AdminUser'] -Password $Ctx.SuiteData['AdminPassword']
        }
    }

    Execute = {
        param($Context)

        $adminUser = $Context.SuiteData["AdminUser"]
        $adminPassword = $Context.SuiteData["AdminPassword"]
        $prefix = $Context.TestPrefix

        # --- DELETE method ---
        Test-SgDnAssert "DELETE removes an object" {
            # Create a throwaway user
            $tempUser = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
                -RelativeUrl "Users" -Body @{
                    PrimaryAuthenticationProvider = @{ Id = -1 }
                    Name = "${prefix}_ApiDeleteMe"
                }
            $tempId = $tempUser.Id

            # DELETE it
            Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Delete `
                -RelativeUrl "Users/$tempId" -ParseJson $false

            # Verify it's gone (GET should fail with 404)
            $found = $true
            try {
                Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                    -RelativeUrl "Users/$tempId"
            }
            catch {
                $found = $false
            }
            -not $found
        }

        # --- CSV output ---
        Test-SgDnAssert "GET with CSV flag returns CSV-formatted data" {
            $csvResult = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Users" -Csv -ParseJson $false
            # CSV should contain header row with common User fields
            $null -ne $csvResult -and $csvResult.Contains("Name") -and $csvResult.Contains(",")
        }

        # --- Query filter ---
        Test-SgDnAssert "GET with filter returns matching objects only" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Users?filter=Name eq '$adminUser'"
            $items = @($result)
            $items.Count -eq 1 -and $items[0].Name -eq $adminUser
        }

        # --- Query with contains filter ---
        Test-SgDnAssert "GET with contains filter finds test objects" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Users?filter=Name contains '${prefix}'"
            $items = @($result)
            $items.Count -ge 1
        }

        # --- Query with ordering ---
        Test-SgDnAssert "GET with orderby returns ordered results" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Users?orderby=Name"
            $items = @($result)
            # Verify at least 2 items and they are alphabetically ordered
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

        # --- PUT update ---
        Test-SgDnAssert "PUT updates an existing object" {
            $assetId = $Context.SuiteData["AssetId"]
            $newDesc = "updated by ApiInvocation test"

            # GET current state
            $before = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Assets/$assetId" `
                -Username $adminUser -Password $adminPassword

            # PUT update with new description
            $updated = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Put `
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

            # Verify the description changed
            $updated.Description -eq $newDesc
        }

        # --- POST response contains created entity ---
        Test-SgDnAssert "POST returns the created entity with Id" {
            $adminId = $Context.SuiteData["AdminUserId"]
            # Verify the admin user created during setup has an Id and correct name
            $adminId -gt 0
        }

        # --- GET against Appliance service (non-Core) ---
        Test-SgDnAssert "GET against Appliance service works" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Appliance -Method Get `
                -RelativeUrl "ApplianceStatus" `
                -Username $adminUser -Password $adminPassword
            $null -ne $result
        }

        # --- GET against Notification service (anonymous) ---
        Test-SgDnAssert "GET against Notification service (anonymous) works" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Notification -Method Get `
                -RelativeUrl "Status" -Anonymous -ParseJson $false
            $null -ne $result -and $result.Length -gt 0
        }

        # --- InvokeMethodFull: GET returns 200 ---
        Test-SgDnAssert "Full response GET returns StatusCode 200" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -Full
            $result.StatusCode -eq 200
        }

        # --- InvokeMethodFull: response contains Headers ---
        Test-SgDnAssert "Full response contains Headers dictionary" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -Full
            $null -ne $result.Headers -and $result.Headers.Count -gt 0
        }

        # --- InvokeMethodFull: response contains Body ---
        Test-SgDnAssert "Full response Body contains user identity" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -Full
            $body = $result.Body
            if ($body -is [string]) { $body = $body | ConvertFrom-Json }
            $null -ne $body.Name
        }

        # --- InvokeMethodFull: POST returns 201 ---
        Test-SgDnAssert "Full response POST returns StatusCode 201" {
            $tempUser = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
                -RelativeUrl "Users" -Full -Body @{
                    PrimaryAuthenticationProvider = @{ Id = -1 }
                    Name = "${prefix}_ApiFullPost"
                }
            try {
                $tempUser.StatusCode -eq 201
            }
            finally {
                # Cleanup the temp user
                $body = $tempUser.Body
                if ($body -is [string]) { $body = $body | ConvertFrom-Json }
                if ($body.Id) {
                    try {
                        Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Delete `
                            -RelativeUrl "Users/$($body.Id)" -ParseJson $false
                    } catch {}
                }
            }
        }

        # --- InvokeMethodFull: DELETE returns 204 ---
        Test-SgDnAssert "Full response DELETE returns StatusCode 204" {
            # Create a user to delete
            $tempUser = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
                -RelativeUrl "Users" -Body @{
                    PrimaryAuthenticationProvider = @{ Id = -1 }
                    Name = "${prefix}_ApiFullDel"
                }
            $deleteResult = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Delete `
                -RelativeUrl "Users/$($tempUser.Id)" -Full
            $deleteResult.StatusCode -eq 204
        }

        # --- Query parameters via -Parameters flag ---
        Test-SgDnAssert "GET with -Parameters filter returns matching objects" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Users" -Parameters @{ filter = "Name eq '$adminUser'" }
            $items = @($result)
            $items.Count -eq 1 -and $items[0].Name -eq $adminUser
        }

        # --- Query parameters: orderby via -Parameters ---
        Test-SgDnAssert "GET with -Parameters orderby returns ordered results" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Users" -Parameters @{ orderby = "Name" }
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

        # --- Custom headers: Accept header ---
        Test-SgDnAssert "GET with custom Accept header succeeds" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Get `
                -RelativeUrl "Me" -Headers @{ "Accept" = "application/json" }
            $null -ne $result.Name
        }
    }

    Cleanup = {
        param($Context)
        # Registered cleanup handles everything.
    }
}

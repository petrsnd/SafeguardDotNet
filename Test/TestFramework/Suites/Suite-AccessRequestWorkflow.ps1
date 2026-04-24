@{
    Name        = "Access Request Workflow"
    Description = "Tests the full access request lifecycle: create, approve, checkout, checkin"
    Tags        = @("workflow", "access-request")

    Setup = {
        param($Context)

        $prefix = $Context.TestPrefix
        $adminUser = "${prefix}_WfAdmin"
        $adminPassword = "2309aseflkasdlf209349qauerA"
        $certUser = "${prefix}_WfCertUser"

        # Compute thumbprint for approver cert user
        Write-Host "    Computing certificate thumbprints..." -ForegroundColor DarkGray
        $userThumbprint = (Get-PfxCertificate $Context.UserCert).Thumbprint
        $Context.SuiteData["UserThumbprint"] = $userThumbprint

        # Pre-cleanup: remove stale objects from previous failed runs (reverse dependency order)
        Write-Host "    Removing stale objects from previous runs..." -ForegroundColor DarkGray
        Remove-SgDnStaleTestObject -Context $Context -Collection "AccessPolicies" -Name "${prefix}_WfPolicy"
        Remove-SgDnStaleTestObject -Context $Context -Collection "Roles" -Name "${prefix}_WfRole"
        Remove-SgDnStaleTestObject -Context $Context -Collection "AssetAccounts" -Name "${prefix}_WfAccount"
        Remove-SgDnStaleTestObject -Context $Context -Collection "Assets" -Name "${prefix}_WfAsset"
        Remove-SgDnStaleTestObject -Context $Context -Collection "Users" -Name $certUser
        Remove-SgDnStaleTestCert -Context $Context -Thumbprint (Get-PfxCertificate $Context.CaCert).Thumbprint
        Remove-SgDnStaleTestCert -Context $Context -Thumbprint (Get-PfxCertificate $Context.RootCert).Thumbprint
        Remove-SgDnStaleTestObject -Context $Context -Collection "Users" -Name $adminUser

        # 1. Create admin user (requester)
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
        Register-SgDnTestCleanup -Description "Delete workflow admin user" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Users/$($Ctx.SuiteData['AdminUserId'])"
        }
        Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Put `
            -RelativeUrl "Users/$($admin.Id)/Password" -Body "'$adminPassword'" -ParseJson $false

        # 2. Upload cert trust chain
        Write-Host "    Uploading certificate trust chain..." -ForegroundColor DarkGray
        $rootCertData = [string](Get-Content -Raw $Context.RootCert)
        $rootCert = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "TrustedCertificates" `
            -Username $adminUser -Password $adminPassword `
            -Body @{ Base64CertificateData = $rootCertData }
        $Context.SuiteData["RootCertId"] = $rootCert.Id
        Register-SgDnTestCleanup -Description "Delete Root CA trust" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "TrustedCertificates/$($Ctx.SuiteData['RootCertId'])"
        }

        $caCertData = [string](Get-Content -Raw $Context.CaCert)
        $caCert = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "TrustedCertificates" `
            -Username $adminUser -Password $adminPassword `
            -Body @{ Base64CertificateData = $caCertData }
        $Context.SuiteData["CaCertId"] = $caCert.Id
        Register-SgDnTestCleanup -Description "Delete Intermediate CA trust" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "TrustedCertificates/$($Ctx.SuiteData['CaCertId'])"
        }

        # 3. Create cert user (approver)
        Write-Host "    Creating certificate user '$certUser'..." -ForegroundColor DarkGray
        $cUser = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "Users" `
            -Username $adminUser -Password $adminPassword `
            -Body @{
                PrimaryAuthenticationProvider = @{
                    Id = -2
                    Identity = $userThumbprint
                }
                Name = $certUser
            }
        $Context.SuiteData["CertUserId"] = $cUser.Id
        Register-SgDnTestCleanup -Description "Delete cert user" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Users/$($Ctx.SuiteData['CertUserId'])"
        }

        # 4. Create asset
        Write-Host "    Creating asset '${prefix}_WfAsset'..." -ForegroundColor DarkGray
        $asset = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "Assets" `
            -Username $adminUser -Password $adminPassword `
            -Body @{
                Name = "${prefix}_WfAsset"
                Description = "test asset for workflow"
                PlatformId = 188
                AssetPartitionId = -1
                NetworkAddress = "fake.wf.address.com"
            }
        $Context.SuiteData["AssetId"] = $asset.Id
        Register-SgDnTestCleanup -Description "Delete asset" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Assets/$($Ctx.SuiteData['AssetId'])" `
                -Username $Ctx.SuiteData['AdminUser'] -Password $Ctx.SuiteData['AdminPassword']
        }

        # 5. Create account on asset
        Write-Host "    Creating account '${prefix}_WfAccount' on asset..." -ForegroundColor DarkGray
        $account = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "AssetAccounts" `
            -Username $adminUser -Password $adminPassword `
            -Body @{
                Name = "${prefix}_WfAccount"
                Asset = @{ Id = $asset.Id }
            }
        $Context.SuiteData["AccountId"] = $account.Id
        Register-SgDnTestCleanup -Description "Delete asset account" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "AssetAccounts/$($Ctx.SuiteData['AccountId'])" `
                -Username $Ctx.SuiteData['AdminUser'] -Password $Ctx.SuiteData['AdminPassword']
        }
        Write-Host "    Setting account password..." -ForegroundColor DarkGray
        Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Put `
            -RelativeUrl "AssetAccounts/$($account.Id)/Password" `
            -Username $adminUser -Password $adminPassword `
            -Body "'$adminPassword'" -ParseJson $false

        # 6. Create role (entitlement) with admin user as member
        Write-Host "    Creating role '${prefix}_WfRole'..." -ForegroundColor DarkGray
        $role = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "Roles" `
            -Username $adminUser -Password $adminPassword `
            -Body @{
                Name = "${prefix}_WfRole"
                Description = "test entitlement for workflow"
                Members = @(@{ Id = $admin.Id })
            }
        $Context.SuiteData["RoleId"] = $role.Id
        Register-SgDnTestCleanup -Description "Delete role" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Roles/$($Ctx.SuiteData['RoleId'])" `
                -Username $Ctx.SuiteData['AdminUser'] -Password $Ctx.SuiteData['AdminPassword']
        }

        # 7. Create access policy with cert user as approver
        Write-Host "    Creating access policy '${prefix}_WfPolicy'..." -ForegroundColor DarkGray
        $policy = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "AccessPolicies" `
            -Username $adminUser -Password $adminPassword `
            -Body @{
                Name = "${prefix}_WfPolicy"
                Description = "test policy for workflow"
                RoleId = $role.Id
                AccessRequestProperties = @{
                    AccessRequestType = "Password"
                    ChangePasswordAfterCheckin = $false
                    ChangeSshKeyAfterCheckin = $false
                }
                ApproverProperties = @{
                    RequireApproval = $true
                }
                ApproverSets = @(
                    @{
                        RequiredApprovers = 1
                        Approvers = @(@{ Id = $cUser.Id })
                    }
                )
                ScopeItems = @(
                    @{
                        ScopeItemType = "Account"
                        Id = $account.Id
                    }
                )
            }
        $Context.SuiteData["PolicyId"] = $policy.Id
        Register-SgDnTestCleanup -Description "Delete access policy" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "AccessPolicies/$($Ctx.SuiteData['PolicyId'])" `
                -Username $Ctx.SuiteData['AdminUser'] -Password $Ctx.SuiteData['AdminPassword']
        }
    }

    Execute = {
        param($Context)

        $adminUser = $Context.SuiteData["AdminUser"]
        $adminPassword = $Context.SuiteData["AdminPassword"]
        $accountId = $Context.SuiteData["AccountId"]
        $assetId = $Context.SuiteData["AssetId"]

        Test-SgDnAssert "Create access request" {
            $request = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
                -RelativeUrl "AccessRequests" `
                -Username $adminUser -Password $adminPassword `
                -Body @{
                    AccessRequestType = "Password"
                    AssetId = $assetId
                    AccountId = $accountId
                }
            $Context.SuiteData["RequestId"] = $request.Id
            # Register cleanup — runs before policy cleanup (LIFO) to unblock dependency chain
            Register-SgDnTestCleanup -Description "Close/delete access request" -Action {
                param($Ctx)
                $reqId = $Ctx.SuiteData['RequestId']
                $au = $Ctx.SuiteData['AdminUser']
                $ap = $Ctx.SuiteData['AdminPassword']
                if ($reqId) {
                    # Try to close the request first (checkin if still checked out, then close)
                    try {
                        Invoke-SgDnSafeguardApi -Context $Ctx -Service Core -Method Post `
                            -RelativeUrl "AccessRequests/$reqId/CheckIn" `
                            -Username $au -Password $ap -ParseJson $false
                    } catch {}
                    try {
                        Invoke-SgDnSafeguardApi -Context $Ctx -Service Core -Method Post `
                            -RelativeUrl "AccessRequests/$reqId/Close" `
                            -Username $au -Password $ap -ParseJson $false
                    } catch {}
                }
            }
            $null -ne $request.Id
        }

        Test-SgDnAssert "Approve access request (via cert user)" {
            $requestId = $Context.SuiteData["RequestId"]
            Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
                -RelativeUrl "AccessRequests/$requestId/Approve" `
                -CertificateFile $Context.UserPfx -CertificatePassword "a" `
                -ParseJson $false
            $true
        }

        Test-SgDnAssert "Checkout password from access request" {
            $requestId = $Context.SuiteData["RequestId"]
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
                -RelativeUrl "AccessRequests/$requestId/CheckOutPassword" `
                -Username $adminUser -Password $adminPassword `
                -ParseJson $false
            $null -ne $result -and $result.Length -gt 0
        }

        Test-SgDnAssert "Checkin access request" {
            $requestId = $Context.SuiteData["RequestId"]
            Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
                -RelativeUrl "AccessRequests/$requestId/CheckIn" `
                -Username $adminUser -Password $adminPassword `
                -ParseJson $false
            $true
        }
    }

    Cleanup = {
        param($Context)
        # Registered cleanup handles everything.
    }
}

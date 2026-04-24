@{
    Name        = "A2A Credential Retrieval"
    Description = "Tests Application-to-Application credential retrieval via certificate auth"
    Tags        = @("a2a", "certificate")

    Setup = {
        param($Context)

        $prefix = $Context.TestPrefix
        $adminUser = "${prefix}_A2aAdmin"
        $adminPassword = "2309aseflkasdlf209349qauerA"
        $certUser = "${prefix}_A2aCertUser"

        # Compute thumbprints
        $userThumbprint = (Get-PfxCertificate $Context.UserCert).Thumbprint
        $rootThumbprint = (Get-PfxCertificate $Context.RootCert).Thumbprint
        $caThumbprint   = (Get-PfxCertificate $Context.CaCert).Thumbprint
        $Context.SuiteData["UserThumbprint"] = $userThumbprint

        # Pre-cleanup: remove stale objects from previous failed runs (reverse dependency order)
        Remove-SgDnStaleTestObject -Context $Context -Collection "A2ARegistrations" -Name "${prefix}_A2aReg"
        Remove-SgDnStaleTestObject -Context $Context -Collection "AssetAccounts" -Name "${prefix}_A2aAccount"
        Remove-SgDnStaleTestObject -Context $Context -Collection "Assets" -Name "${prefix}_A2aAsset"
        Remove-SgDnStaleTestObject -Context $Context -Collection "Users" -Name $certUser
        Remove-SgDnStaleTestCert -Context $Context -Thumbprint $caThumbprint
        Remove-SgDnStaleTestCert -Context $Context -Thumbprint $rootThumbprint
        Remove-SgDnStaleTestObject -Context $Context -Collection "Users" -Name $adminUser

        # 1. Create admin user
        $admin = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "Users" -Body @{
                PrimaryAuthenticationProvider = @{ Id = -1 }
                Name = $adminUser
                AdminRoles = @('GlobalAdmin','Auditor','AssetAdmin','ApplianceAdmin','PolicyAdmin','UserAdmin','HelpdeskAdmin','OperationsAdmin')
            }
        $Context.SuiteData["AdminUserId"] = $admin.Id
        Register-SgDnTestCleanup -Description "Delete A2A admin user" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Users/$($Ctx.SuiteData['AdminUserId'])"
        }
        Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Put `
            -RelativeUrl "Users/$($admin.Id)/Password" -Body "'$adminPassword'" -ParseJson $false
        $Context.SuiteData["AdminUser"] = $adminUser
        $Context.SuiteData["AdminPassword"] = $adminPassword

        # 2. Upload cert trust chain
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

        # 3. Create certificate user
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
        Register-SgDnTestCleanup -Description "Delete A2A certificate user" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Users/$($Ctx.SuiteData['CertUserId'])"
        }

        # 4. Create asset
        $asset = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "Assets" `
            -Username $adminUser -Password $adminPassword `
            -Body @{
                Name = "${prefix}_A2aAsset"
                Description = "test asset for A2A credential retrieval"
                PlatformId = 188
                AssetPartitionId = -1
                NetworkAddress = "fake.a2a.address.com"
            }
        $Context.SuiteData["AssetId"] = $asset.Id
        Register-SgDnTestCleanup -Description "Delete asset" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "Assets/$($Ctx.SuiteData['AssetId'])" `
                -Username $Ctx.SuiteData['AdminUser'] -Password $Ctx.SuiteData['AdminPassword']
        }

        # 5. Create account on asset
        $account = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "AssetAccounts" `
            -Username $adminUser -Password $adminPassword `
            -Body @{
                Name = "${prefix}_A2aAccount"
                Asset = @{ Id = $asset.Id }
            }
        $Context.SuiteData["AccountId"] = $account.Id
        Register-SgDnTestCleanup -Description "Delete asset account" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "AssetAccounts/$($Ctx.SuiteData['AccountId'])" `
                -Username $Ctx.SuiteData['AdminUser'] -Password $Ctx.SuiteData['AdminPassword']
        }

        # Set account password
        Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Put `
            -RelativeUrl "AssetAccounts/$($account.Id)/Password" `
            -Username $adminUser -Password $adminPassword `
            -Body "'$adminPassword'" -ParseJson $false

        # 6. Create A2A registration
        $a2aReg = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "A2ARegistrations" `
            -Username $adminUser -Password $adminPassword `
            -Body @{
                AppName = "${prefix}_A2aReg"
                VisibleToCertificateUsers = $true
                BidirectionalEnabled = $true
                Description = "test a2a registration for SafeguardDotNet"
                CertificateUserId = $cUser.Id
            }
        $Context.SuiteData["A2aRegId"] = $a2aReg.Id
        Register-SgDnTestCleanup -Description "Delete A2A registration" -Action {
            param($Ctx)
            Remove-SgDnSafeguardTestObject -Context $Ctx `
                -RelativeUrl "A2ARegistrations/$($Ctx.SuiteData['A2aRegId'])" `
                -Username $Ctx.SuiteData['AdminUser'] -Password $Ctx.SuiteData['AdminPassword']
        }

        # 7. Add retrievable account to A2A registration
        $retrievable = Invoke-SgDnSafeguardApi -Context $Context -Service Core -Method Post `
            -RelativeUrl "A2ARegistrations/$($a2aReg.Id)/RetrievableAccounts" `
            -Username $adminUser -Password $adminPassword `
            -Body @{ AccountId = $account.Id }
        $Context.SuiteData["ApiKey"] = $retrievable.ApiKey

        # 8. Enable A2A service
        Invoke-SgDnSafeguardApi -Context $Context -Service Appliance -Method Post `
            -RelativeUrl "A2AService/Enable" `
            -Username $adminUser -Password $adminPassword `
            -ParseJson $false

        # Register cert store cleanup last (runs first in LIFO)
        Register-SgDnTestCleanup -Description "Remove cert from user store (if imported)" -Action {
            param($Ctx)
            $tp = $Ctx.SuiteData['UserThumbprint']
            if ($tp -and (Test-Path "Cert:\CurrentUser\My\$tp")) {
                Remove-Item "Cert:\CurrentUser\My\$tp" -ErrorAction SilentlyContinue
            }
        }
    }

    Execute = {
        param($Context)

        $apiKey = $Context.SuiteData["ApiKey"]

        Test-SgDnAssert "A2A list retrievable accounts via PFX file" {
            $result = Invoke-SgDnSafeguardA2a -Context $Context `
                -ApiKey $apiKey `
                -CertificateFile $Context.UserPfx -CertificatePassword "a" `
                -RetrievableAccounts
            $null -ne $result
        }

        Test-SgDnAssert "A2A credential retrieval via PFX file" {
            $result = Invoke-SgDnSafeguardA2a -Context $Context `
                -ApiKey $apiKey `
                -CertificateFile $Context.UserPfx -CertificatePassword "a"
            $null -ne $result
        }

        Test-SgDnAssert "A2A credential retrieval via PFX file as data buffer" {
            $result = Invoke-SgDnSafeguardA2a -Context $Context `
                -ApiKey $apiKey `
                -CertificateFile $Context.UserPfx -CertificatePassword "a" `
                -CertificateAsData
            $null -ne $result
        }

        Test-SgDnAssert "A2A credential retrieval from User Certificate Store" {
            $tp = $Context.SuiteData["UserThumbprint"]
            Import-PfxCertificate $Context.UserPfx `
                -CertStoreLocation Cert:\CurrentUser\My `
                -Password (ConvertTo-SecureString -AsPlainText 'a' -Force) | Out-Null
            try {
                $result = Invoke-SgDnSafeguardA2a -Context $Context `
                    -ApiKey $apiKey `
                    -Thumbprint $tp -CertificatePassword "a"
                $null -ne $result
            }
            finally {
                if (Test-Path "Cert:\CurrentUser\My\$tp") {
                    Remove-Item "Cert:\CurrentUser\My\$tp" -ErrorAction SilentlyContinue
                }
            }
        }

        Test-SgDnAssert "A2A credential put (set new password) from User Certificate Store" {
            $tp = $Context.SuiteData["UserThumbprint"]
            Import-PfxCertificate $Context.UserPfx `
                -CertStoreLocation Cert:\CurrentUser\My `
                -Password (ConvertTo-SecureString -AsPlainText 'a' -Force) | Out-Null
            try {
                Invoke-SgDnSafeguardA2a -Context $Context `
                    -ApiKey $apiKey `
                    -Thumbprint $tp -CertificatePassword "a" `
                    -NewPassword -ParseJson $false
                $true
            }
            finally {
                if (Test-Path "Cert:\CurrentUser\My\$tp") {
                    Remove-Item "Cert:\CurrentUser\My\$tp" -ErrorAction SilentlyContinue
                }
            }
        }

        # --- Filter tests ---

        $accountName = "$($Context.TestPrefix)_A2aAccount"

        Test-SgDnAssert "A2A filter retrievable accounts by valid property" {
            $result = Invoke-SgDnSafeguardA2a -Context $Context `
                -ApiKey $apiKey `
                -CertificateFile $Context.UserPfx -CertificatePassword "a" `
                -RetrievableAccounts -Filter "AccountName eq '$accountName'"
            ($null -ne $result) -and ($result.Count -ge 1)
        }

        Test-SgDnAssert "A2A filter with no matches returns empty list" {
            $raw = Invoke-SgDnSafeguardA2a -Context $Context `
                -ApiKey $apiKey `
                -CertificateFile $Context.UserPfx -CertificatePassword "a" `
                -RetrievableAccounts -Filter "AccountName eq 'NonExistentAccount_xyz_999'" `
                -ParseJson $false
            # -R lists filtered accounts ("[]") then also retrieves the password;
            # just verify no error was thrown and the empty array is in the output
            $raw -match '\[\]'
        }

        Test-SgDnAssert "A2A garbage filter gives useful error" {
            $threw = $false
            try {
                Invoke-SgDnSafeguardA2a -Context $Context `
                    -ApiKey $apiKey `
                    -CertificateFile $Context.UserPfx -CertificatePassword "a" `
                    -RetrievableAccounts -Filter "This eq 'broken'"
            }
            catch {
                $threw = ($_.Exception.Message -match "invalid filter" -or
                          $_.Exception.Message -match "not a valid filter" -or
                          $_.Exception.Message -match "BadRequest" -or
                          $_.Exception.Message -match "400")
            }
            $threw
        }

        Test-SgDnAssert "A2A malformed filter expression gives useful error" {
            $threw = $false
            try {
                Invoke-SgDnSafeguardA2a -Context $Context `
                    -ApiKey $apiKey `
                    -CertificateFile $Context.UserPfx -CertificatePassword "a" `
                    -RetrievableAccounts -Filter "not even close to a filter!!!"
            }
            catch {
                $threw = ($_.Exception.Message -match "invalid filter" -or
                          $_.Exception.Message -match "not a valid filter" -or
                          $_.Exception.Message -match "error" -or
                          $_.Exception.Message -match "BadRequest" -or
                          $_.Exception.Message -match "400")
            }
            $threw
        }
    }

    Cleanup = {
        param($Context)
        # Registered cleanup handles everything.
    }
}

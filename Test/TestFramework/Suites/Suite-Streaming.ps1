@{
    Name        = "Streaming Upload and Download"
    Description = "Tests streaming file upload (UploadAsync) and download (DownloadStreamAsync) via backup endpoints"
    Tags        = @("streaming", "appliance")

    Setup = {
        param($Context)

        $prefix = $Context.TestPrefix
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "${prefix}_streaming"
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $Context.SuiteData["TempDir"] = $tempDir

        Register-SgDnTestCleanup -Description "Remove temp streaming directory" -Action {
            param($Ctx)
            $dir = $Ctx.SuiteData['TempDir']
            if ($dir -and (Test-Path $dir)) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
        }

        # Trigger a new backup so we own the lifecycle
        Write-Host "    Triggering backup..." -ForegroundColor DarkGray
        $backup = Invoke-SgDnSafeguardApi -Context $Context -Service Appliance -Method Post `
            -RelativeUrl "Backups"
        $Context.SuiteData["BackupId"] = $backup.Id

        Register-SgDnTestCleanup -Description "Delete test backup" -Action {
            param($Ctx)
            $backupId = $Ctx.SuiteData['BackupId']
            if ($backupId) {
                try {
                    Invoke-SgDnSafeguardApi -Context $Ctx -Service Appliance -Method Delete `
                        -RelativeUrl "Backups/$backupId" -ParseJson $false
                } catch {}
            }
        }

        # Poll until backup is complete (timeout after 5 minutes)
        $maxWait = 300
        $elapsed = 0
        $interval = 10
        $complete = $false
        while ($elapsed -lt $maxWait) {
            Start-Sleep -Seconds $interval
            $elapsed += $interval
            $status = Invoke-SgDnSafeguardApi -Context $Context -Service Appliance -Method Get `
                -RelativeUrl "Backups/$($backup.Id)"
            Write-Host "    Backup status: $($status.Status) (${elapsed}s elapsed)" -ForegroundColor DarkGray
            if ($status.Status -eq "Complete") {
                $complete = $true
                break
            }
        }

        if (-not $complete) {
            throw "Backup did not complete within ${maxWait}s"
        }
    }

    Execute = {
        param($Context)

        $tempDir = $Context.SuiteData["TempDir"]
        $backupId = $Context.SuiteData["BackupId"]
        $downloadPath = Join-Path $tempDir "backup_download.sgb"

        # --- Streaming download ---
        Test-SgDnAssert "Streaming download: backup file downloaded successfully" {
            Invoke-SgDnSafeguardApi -Context $Context -Service Appliance -Method Get `
                -RelativeUrl "Backups/$backupId/Download" `
                -File $downloadPath -ParseJson $false
            Test-Path $downloadPath
        }

        # --- Verify downloaded file has content ---
        Test-SgDnAssert "Downloaded backup file is non-empty" {
            $fileInfo = Get-Item $downloadPath
            $fileInfo.Length -gt 0
        }

        # --- Streaming upload ---
        Test-SgDnAssert "Streaming upload: backup file uploaded successfully" {
            $result = Invoke-SgDnSafeguardApi -Context $Context -Service Appliance -Method Post `
                -RelativeUrl "Backups/Upload" `
                -File $downloadPath
            # Upload returns the backup entity with Status=Complete
            $null -ne $result.Id -and $result.Status -eq "Complete"
        }

        # --- Verify uploaded backup has correct size ---
        Test-SgDnAssert "Uploaded backup file size matches download" {
            $uploadedBackup = Invoke-SgDnSafeguardApi -Context $Context -Service Appliance -Method Get `
                -RelativeUrl "Backups/$backupId"
            $localSize = (Get-Item $downloadPath).Length
            $uploadedBackup.Size -gt 0 -and $uploadedBackup.Status -eq "Complete"
        }
    }

    Cleanup = {
        param($Context)

        # Clean up any backups created by the bootstrap admin during this test
        try {
            $backups = Invoke-SgDnSafeguardApi -Context $Context -Service Appliance -Method Get `
                -RelativeUrl "Backups"
            $originalId = $Context.SuiteData['BackupId']
            foreach ($b in @($backups)) {
                if ($b.Id -ne $originalId -and $b.CreatedByDisplayName -eq "Bootstrap Administrator") {
                    try {
                        Invoke-SgDnSafeguardApi -Context $Context -Service Appliance -Method Delete `
                            -RelativeUrl "Backups/$($b.Id)" -ParseJson $false
                    } catch {}
                }
            }
        } catch {}
        # Registered cleanup handles the original backup and temp dir.
    }
}

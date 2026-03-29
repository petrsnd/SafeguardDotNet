@{
    Name        = "Streaming Upload and Download"
    Description = "Tests streaming file download (downloadStream) and upload (uploadStream) via backup endpoints"
    Tags        = @("streaming", "appliance")

    Setup = {
        param($Context)
    }

    Execute = {
        param($Context)

        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sgj-streaming-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $downloadPath = Join-Path $tempDir "backup-download.sgb"

        try {
            # --- Step 1: Trigger a backup ---
            $backup = Invoke-SgJSafeguardApi -Context $Context -Service Appliance -Method Post `
                -RelativeUrl "Backups"
            $backupId = $backup.Id

            Test-SgJAssert "Trigger backup: received backup ID" {
                $null -ne $backupId
            }

            # --- Step 2: Poll until backup is complete (5 min timeout) ---
            $timeout = (Get-Date).AddMinutes(5)
            $backupComplete = $false
            while ((Get-Date) -lt $timeout) {
                $backupInfo = Invoke-SgJSafeguardApi -Context $Context -Service Appliance -Method Get `
                    -RelativeUrl "Backups/$backupId"
                if ($backupInfo.Status -eq "Complete") {
                    $backupComplete = $true
                    break
                }
                Start-Sleep -Seconds 5
            }

            Test-SgJAssert "Backup completed within timeout" {
                $backupComplete -eq $true
            }

            # --- Step 3: Streaming download ---
            $downloadResult = Invoke-SgJSafeguardApi -Context $Context -Service Appliance -Method Get `
                -RelativeUrl "Backups/$backupId/Download" `
                -File $downloadPath -ParseJson $false

            Test-SgJAssert "Streaming download: backup file created" {
                Test-Path $downloadPath
            }

            $fileSize = (Get-Item $downloadPath).Length

            Test-SgJAssert "Streaming download: backup file is non-empty" {
                $fileSize -gt 0
            }

            # --- Step 4: Streaming upload ---
            $uploadResult = Invoke-SgJSafeguardApi -Context $Context -Service Appliance -Method Post `
                -RelativeUrl "Backups/Upload" `
                -File $downloadPath

            Test-SgJAssert "Streaming upload: response has Id and Complete status" {
                $null -ne $uploadResult.Id -and $uploadResult.Status -eq "Complete"
            }

        } finally {
            # Cleanup temp files
            if (Test-Path $tempDir) {
                Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
            }
            # Cleanup backup if created
            if ($backupId) {
                try {
                    Invoke-SgJSafeguardApi -Context $Context -Service Appliance -Method Delete `
                        -RelativeUrl "Backups/$backupId" -ParseJson $false
                } catch {
                    Write-Verbose "Cleanup: could not delete backup $backupId - $($_.Exception.Message)"
                }
            }
        }
    }

    Cleanup = {
        param($Context)
    }
}

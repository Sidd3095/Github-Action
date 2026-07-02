$ErrorActionPreference = "Stop"

$SitePath   = $env:IIS_SITE_PATH
$BackupRoot = $env:BACKUP_PATH
$Website    = $env:WEBSITE_URL

#---------------------------------------------
# Validate Paths
#---------------------------------------------
if (!(Test-Path $SitePath)) {
    throw "IIS Site Path does not exist: $SitePath"
}

if (!(Test-Path $BackupRoot)) {
    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
}

$Time   = Get-Date -Format "yyyyMMdd_HHmmss"
$Backup = Join-Path $BackupRoot $Time

Write-Host "==============================================="
Write-Host "IIS Site Path : $SitePath"
Write-Host "Backup Folder : $Backup"
Write-Host "Website URL   : $Website"
Write-Host "==============================================="

#---------------------------------------------
# Find Angular Build
#---------------------------------------------
Write-Host "Finding Angular Build..."

$Dist = Get-ChildItem ".\dist" -Directory | Select-Object -First 1

if (!$Dist) {
    throw "Angular build not found."
}

$Source = Join-Path $Dist.FullName "browser"

if (!(Test-Path $Source)) {
    $Source = $Dist.FullName
}

Write-Host "Angular Build Path : $Source"

#---------------------------------------------
# Backup Current Website
#---------------------------------------------
Write-Host "Creating Backup..."

New-Item -ItemType Directory -Force -Path $Backup | Out-Null

robocopy $SitePath $Backup /E

if ($LASTEXITCODE -ge 8) {
    throw "Backup Failed. Robocopy Exit Code : $LASTEXITCODE"
}

Write-Host "Backup Completed."

#---------------------------------------------
# Delete Existing Files Except web.config
#---------------------------------------------
Write-Host "Removing Existing Files..."

Get-ChildItem $SitePath -Force |
Where-Object { $_.Name -ne "web.config" } |
Remove-Item -Recurse -Force

#---------------------------------------------
# Copy New Build
#---------------------------------------------
Write-Host "Deploying New Build..."

robocopy $Source $SitePath /E /XF web.config

if ($LASTEXITCODE -ge 8) {
    throw "Deployment Failed. Robocopy Exit Code : $LASTEXITCODE"
}

Write-Host "Deployment Completed."

#---------------------------------------------
# Health Check (Retry)
#---------------------------------------------
Write-Host "Running Health Check..."

$Success = $false

for($i=1; $i -le 10; $i++)
{
    try
    {
        $Response = Invoke-WebRequest `
            -Uri $Website `
            -TimeoutSec 10 `
            -UseBasicParsing

        if($Response.StatusCode -eq 200)
        {
            $Success = $true
            break
        }
    }
    catch
    {
        Write-Host "Attempt $i failed..."
        Start-Sleep -Seconds 3
    }
}

if(!$Success)
{
    Write-Host "Deployment Failed."
    Write-Host "Rolling Back..."

    powershell.exe `
        -ExecutionPolicy Bypass `
        -File ".\scripts\rollback.ps1" `
        -BackupFolder $Backup

    throw "Health Check Failed. Rollback Completed."
}

Write-Host "Health Check Passed."

#---------------------------------------------
# Keep Last 10 Backups
#---------------------------------------------
Write-Host "Cleaning Old Backups..."

Get-ChildItem $BackupRoot -Directory |
Sort-Object CreationTime -Descending |
Select-Object -Skip 10 |
Remove-Item -Recurse -Force

Write-Host "Old Backup Cleanup Completed."

Write-Host "==============================================="
Write-Host "Deployment Successful"
Write-Host "==============================================="

exit 0
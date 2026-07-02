$ErrorActionPreference = "Stop"

$SitePath = $env:IIS_SITE_PATH
$BackupRoot = $env:BACKUP_PATH
$Website = $env:WEBSITE_URL

$Time = Get-Date -Format "yyyyMMdd_HHmmss"
$Backup = Join-Path $BackupRoot $Time

Write-Host "Finding Angular Build..."

$Dist = Get-ChildItem ".\dist" | Select-Object -First 1

if(!$Dist){
    throw "Angular build not found."
}

$Source = Join-Path $Dist.FullName "browser"

if(!(Test-Path $Source)){
    $Source = $Dist.FullName
}

Write-Host "Creating Backup..."

New-Item -ItemType Directory -Force -Path $Backup | Out-Null

Copy-Item "$SitePath\*" `
          $Backup `
          -Recurse `
          -Force

Write-Host "Backup Completed."

Write-Host "Removing Existing Files..."

Get-ChildItem $SitePath |
Remove-Item -Force -Recurse

Write-Host "Copying New Build..."

Copy-Item "$Source\*" `
          $SitePath `
          -Force `
          -Recurse

Write-Host "Waiting for IIS..."

Start-Sleep -Seconds 10

Write-Host "Running Health Check..."

try{

    $response = Invoke-WebRequest `
        -Uri $Website `
        -UseBasicParsing `
        -TimeoutSec 30

    if($response.StatusCode -eq 200){

        Write-Host "Health Check Passed."

    }
    else{

        throw "Health Check Failed."

    }

}
catch{

    Write-Host "Deployment Failed."

    Write-Host "Rolling Back..."

    powershell.exe -ExecutionPolicy Bypass `
        -File ".\scripts\rollback.ps1" `
        -BackupFolder $Backup

    throw
}

Write-Host "Deployment Successful."
param(
    [string]$BackupFolder
)

$SitePath = $env:IIS_SITE_PATH

Write-Host "Rollback Started..."

Get-ChildItem $SitePath -Force |
Where-Object { $_.Name -ne "web.config" } |
Remove-Item -Recurse -Force

robocopy $BackupFolder $SitePath /E /XF web.config

if ($LASTEXITCODE -ge 8) {
    throw "Rollback Failed. Robocopy Exit Code : $LASTEXITCODE"
}

Write-Host "Rollback Completed."
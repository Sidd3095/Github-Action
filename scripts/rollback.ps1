param(

[string]$BackupFolder

)

$SitePath = $env:IIS_SITE_PATH

Write-Host "Rollback Started..."

Get-ChildItem $SitePath |
Remove-Item -Force -Recurse

Copy-Item "$BackupFolder\*" `
          $SitePath `
          -Force `
          -Recurse

Write-Host "Rollback Completed."
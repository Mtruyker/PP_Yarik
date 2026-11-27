param(
    [string]$Database = 'prodahi_practice',
    [string]$PgHost = 'localhost',
    [string]$PgUser = 'postgres',
    [string]$PgBin = 'C:\Program Files\PostgreSQL\17\bin',
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\backups')
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutputDirectory | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupPath = Join-Path (Resolve-Path $OutputDirectory) "$($Database)_$stamp.dump"
& "$PgBin\pg_dump.exe" -h $PgHost -U $PgUser -d $Database -Fc --no-owner --no-acl -f $backupPath
if ($LASTEXITCODE -ne 0) { throw 'pg_dump failed; backup is not complete.' }
& "$PgBin\pg_restore.exe" --list $backupPath | Out-File "$backupPath.list.txt" -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw 'Archive listing failed.' }
Get-FileHash -LiteralPath $backupPath -Algorithm SHA256 | Format-List | Out-File "$backupPath.sha256.txt" -Encoding utf8
Write-Output $backupPath
# Listing alone does not prove recoverability. Run Restore-Database.ps1 and compare data.

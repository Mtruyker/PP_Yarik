param(
    [Parameter(Mandatory=$true)][string]$BackupPath,
    [string]$TargetDatabase = ('prodahi_restore_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [string]$PgHost = 'localhost',
    [string]$PgUser = 'postgres',
    [string]$PgBin = 'C:\Program Files\PostgreSQL\17\bin'
)
$ErrorActionPreference = 'Stop'
if ($TargetDatabase -notmatch '^prodahi_restore_[a-zA-Z0-9_]+$') { throw 'Use a separate prodahi_restore_* database.' }
if (!(Test-Path -LiteralPath $BackupPath)) { throw 'Backup not found.' }
& "$PgBin\createdb.exe" -h $PgHost -U $PgUser $TargetDatabase
if ($LASTEXITCODE -ne 0) { throw 'Target must be a new database; existing databases are not overwritten.' }
& "$PgBin\pg_restore.exe" -h $PgHost -U $PgUser -d $TargetDatabase --no-owner --no-acl --exit-on-error --single-transaction $BackupPath
if ($LASTEXITCODE -ne 0) { throw 'Restore failed; target retained for diagnostics.' }
& "$PgBin\psql.exe" -h $PgHost -U $PgUser -d $TargetDatabase -v ON_ERROR_STOP=1 -c 'REVOKE ALL ON SCHEMA inventory FROM PUBLIC; REVOKE ALL ON ALL FUNCTIONS IN SCHEMA inventory FROM PUBLIC; SELECT count(*) AS products, sum(stock) AS units FROM inventory.products; SELECT count(*) AS movements FROM inventory.movements;'
if ($LASTEXITCODE -ne 0) { throw 'Verification failed.' }
Write-Output "Restored to $TargetDatabase. This isolated restore has no application grants."

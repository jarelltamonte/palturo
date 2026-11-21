# Remove the tagged production mocks.
#
#   powershell -ExecutionPolicy Bypass -File supabase\tests\remove_mock_accounts.ps1 -Confirm
#
# Requires a Management API PAT in SUPABASE_PAT or ..\palturo\.env.cli.

param(
    [string]$ProjectRef = 'yjcrfgvenilptrnudvcb',
    [switch]$Confirm
)

$ErrorActionPreference = 'Stop'

if (-not $Confirm) {
    throw 'This deletes the tagged mocks. Re-run with -Confirm after reviewing the count.'
}

$pat = $env:SUPABASE_PAT
if ([string]::IsNullOrWhiteSpace($pat)) {
    $candidate = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'palturo\.env.cli'
    if (Test-Path $candidate) {
        $pat = (Get-Content $candidate | Where-Object { $_ -match '^\s*SUPABASE_PAT\s*=' } | Select-Object -First 1) `
            -replace '^\s*SUPABASE_PAT\s*=\s*', '' -replace '"', ''
    }
}
if ([string]::IsNullOrWhiteSpace($pat)) {
    throw 'Missing SUPABASE_PAT. Set it or add ..\palturo\.env.cli.'
}
$pat = $pat.Trim()

$headers = @{ Authorization = "Bearer $pat"; 'Content-Type' = 'application/json' }
$query = {
    param([string]$sql)
    $body = @{ query = $sql } | ConvertTo-Json -Depth 3
    Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ProjectRef/database/query" `
        -Method Post -Headers $headers -Body $body
}

$before = & $query "select count(*) as mocks from auth.users where email like 'mock%@palturo.dev' and coalesce((raw_user_meta_data ->> 'mock')::boolean, false);"
$count = [int]$before.value[0].mocks
Write-Host "Tagged mocks to remove: $count"
if ($count -eq 0) {
    Write-Host 'Nothing to remove.'
    exit 0
}

$sql = Get-Content (Join-Path $PSScriptRoot 'remove_mock_accounts.sql') -Raw
& $query $sql | Out-Null

$after = & $query "select count(*) as mocks from auth.users where email like 'mock%@palturo.dev';"
Write-Host "Remaining mock-tagged users: $([int]$after.value[0].mocks)"

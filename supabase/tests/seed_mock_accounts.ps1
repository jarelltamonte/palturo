# Create the 20 tagged production mocks.
#
#   $env:SUPABASE_PAT = '<management api pat>'
#   powershell -ExecutionPolicy Bypass -File supabase\tests\seed_mock_accounts.ps1
#
# Then apply seed_mock_accounts.sql with the Management API and generate
# embeddings for each account (magic-link session + generate-embeddings).
# Remove later with remove_mock_accounts.ps1 -Confirm.

param(
    [string]$ProjectRef = 'yjcrfgvenilptrnudvcb'
)

$ErrorActionPreference = 'Stop'

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

$keys = Invoke-RestMethod -Uri "https://api.supabase.com/v1/projects/$ProjectRef/api-keys" `
    -Headers @{ Authorization = "Bearer $pat" }
$anon = ($keys | Where-Object { $_.name -eq 'anon' } | Select-Object -First 1).api_key
$svc = ($keys | Where-Object { $_.name -eq 'service_role' } | Select-Object -First 1).api_key
if ([string]::IsNullOrWhiteSpace($anon) -or [string]::IsNullOrWhiteSpace($svc)) {
    throw 'Could not read project API keys.'
}

$accounts = @(
    @('mock01@palturo.dev', 'Maria Clara', 'Santos'),
    @('mock02@palturo.dev', 'Jose Rizal', 'Reyes'),
    @('mock03@palturo.dev', 'Andres Bonifacio', 'Cruz'),
    @('mock04@palturo.dev', 'Gabriela', 'Silang'),
    @('mock05@palturo.dev', 'Apolinario', 'Mabini'),
    @('mock06@palturo.dev', 'Melchora', 'Aquino'),
    @('mock07@palturo.dev', 'Juan', 'Luna'),
    @('mock08@palturo.dev', 'Fernando', 'Amorsolo'),
    @('mock09@palturo.dev', 'Liza', 'Macuja'),
    @('mock10@palturo.dev', 'Lea', 'Salonga'),
    @('mock11@palturo.dev', 'Mikaela', 'Santiago'),
    @('mock12@palturo.dev', 'Paolo', 'Delgado'),
    @('mock13@palturo.dev', 'Trina', 'Villareal'),
    @('mock14@palturo.dev', 'Enzo', 'Ramirez'),
    @('mock15@palturo.dev', 'Bianca', 'Ocampo'),
    @('mock16@palturo.dev', 'Rico', 'Salcedo'),
    @('mock17@palturo.dev', 'Nadia', 'Bautista'),
    @('mock18@palturo.dev', 'Luis', 'Montenegro'),
    @('mock19@palturo.dev', 'Camille', 'Soriano'),
    @('mock20@palturo.dev', 'Diego', 'Fajardo')
)

$headers = @{ apikey = $anon; Authorization = "Bearer $svc" }
$created = 0
$existing = 0

foreach ($account in $accounts) {
    $email, $first, $last = $account
    $body = @{
        email = $email
        password = 'MockPass!2026'
        email_confirm = $true
        user_metadata = @{
            first_name = $first
            last_name = $last
            mock = $true
            mock_batch = '2026-11-22'
        }
    } | ConvertTo-Json -Depth 4

    try {
        Invoke-RestMethod -Uri "https://$ProjectRef.supabase.co/auth/v1/admin/users" `
            -Method Post -Headers $headers -ContentType 'application/json' -Body $body | Out-Null
        $created++
        Write-Host "created $email"
    } catch {
        $detail = $_.ErrorDetails.Message
        if ($detail -match 'already|registered|exists') {
            $existing++
            Write-Host "exists  $email"
        } else {
            throw "Failed to create $email :: $detail"
        }
    }
}

Write-Host "done: $created created, $existing already present"
Write-Host 'Next: apply seed_mock_accounts.sql, then generate embeddings, then clear match caches.'

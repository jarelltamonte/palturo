# Create the 20 local integration accounts through the Auth Admin API.
#
# Run from the repository root with the local stack up:
#   powershell -ExecutionPolicy Bypass -File supabase\tests\seed_local_accounts.ps1
#
# Then apply the data fixtures:
#   docker exec -i supabase_db_palturo psql -U postgres -d postgres `
#     -v ON_ERROR_STOP=1 < supabase/tests/seed_local_accounts.sql
#   docker exec -i supabase_db_palturo psql -U postgres -d postgres `
#     -v ON_ERROR_STOP=1 < supabase/tests/seed_local_embeddings.sql
#
# Passwords are the same for every fixture account: TestPass123!

$ErrorActionPreference = 'Stop'

# npx writes service messages to stderr; do not let PowerShell turn them into
# terminating errors.
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$status = cmd /c "npx --yes supabase@3.1.0 status -o env 2>nul"
$ErrorActionPreference = $previous
$anon = ($status | Where-Object { $_ -match '^ANON_KEY=' } | Select-Object -First 1) -replace '^ANON_KEY=', '' -replace '"', ''
$svc = ($status | Where-Object { $_ -match '^SERVICE_ROLE_KEY=' } | Select-Object -First 1) -replace '^SERVICE_ROLE_KEY=', '' -replace '"', ''
if ([string]::IsNullOrWhiteSpace($anon) -or [string]::IsNullOrWhiteSpace($svc)) {
    throw 'Local Supabase is not running. Start it with: npx supabase@3.1.0 start'
}

$accounts = @(
    @('marisol.rivera@example.test', 'Marisol', 'Rivera'),
    @('diego.santos@example.test', 'Diego', 'Santos'),
    @('althea.cruz@example.test', 'Althea', 'Cruz'),
    @('rafael.mendoza@example.test', 'Rafael', 'Mendoza'),
    @('lourdes.bautista@example.test', 'Lourdes', 'Bautista'),
    @('emilio.garcia@example.test', 'Emilio', 'Garcia'),
    @('bianca.reyes@example.test', 'Bianca', 'Reyes'),
    @('marco.villanueva@example.test', 'Marco', 'Villanueva'),
    @('carmela.delacruz@example.test', 'Carmela', 'Dela Cruz'),
    @('nathaniel.ramos@example.test', 'Nathaniel', 'Ramos'),
    @('sofia.aquino@example.test', 'Sofia', 'Aquino'),
    @('gabriel.navarro@example.test', 'Gabriel', 'Navarro'),
    @('isabella.torres@example.test', 'Isabella', 'Torres'),
    @('joaquin.castillo@example.test', 'Joaquin', 'Castillo'),
    @('camille.domingo@example.test', 'Camille', 'Domingo'),
    @('elias.mercado@example.test', 'Elias', 'Mercado'),
    @('teresa.salazar@example.test', 'Teresa', 'Salazar'),
    @('miguel.ferrer@example.test', 'Miguel', 'Ferrer'),
    @('patricia.lim@example.test', 'Patricia', 'Lim'),
    @('andres.velasco@example.test', 'Andres', 'Velasco')
)

$headers = @{ apikey = $anon; Authorization = "Bearer $svc" }
$created = 0
$existing = 0

foreach ($account in $accounts) {
    $email, $first, $last = $account
    $body = @{
        email = $email
        password = 'TestPass123!'
        email_confirm = $true
        user_metadata = @{ first_name = $first; last_name = $last }
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri 'http://127.0.0.1:54321/auth/v1/admin/users' `
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

# Deploy PalTuro Supabase Edge Functions using the PAT in palturo/.env.cli.
# Never put this PAT in .env / --dart-define; it is an account-level token.

$ErrorActionPreference = 'Stop'

# Accept the token from the environment, the repo root, or the sibling
# experimental checkout. Never put this PAT in .env / --dart-define; it is an
# account-level token and must stay out of the client build.
$pat = $env:SUPABASE_PAT
$envFile = $null
if ([string]::IsNullOrWhiteSpace($pat)) {
    $candidates = @(
        (Join-Path (Split-Path -Parent $PSScriptRoot) '.env.cli'),
        (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'palturo\.env.cli')
    )
    $envFile = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $envFile) {
        throw "Missing .env.cli. Set SUPABASE_PAT or add .env.cli to the repo root."
    }
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*SUPABASE_PAT\s*=\s*(.+?)\s*$') {
            $pat = $matches[1].Trim()
        }
    }
}

if ([string]::IsNullOrWhiteSpace($pat) -or $pat -eq 'REPLACE_AND_ROTATE') {
    throw "Set a real SUPABASE_PAT (environment or .env.cli) before deploying."
}

$env:SUPABASE_ACCESS_TOKEN = $pat
try {
    $projectRef = 'yjcrfgvenilptrnudvcb'
    $functions = @(
        'classify-skill',
        'generate-embeddings',
        'get-matches',
        'admin-api',
        'moderate-notes',
        'delete-account'
    )

    foreach ($fn in $functions) {
        Write-Host "Deploying $fn..."
        npx --yes supabase@3.1.0 functions deploy $fn --remote=$projectRef --use-api --yes
        if ($LASTEXITCODE -ne 0) {
            throw "Deployment failed for $fn."
        }
    }

    Write-Host 'All functions deployed.'
}
finally {
    Remove-Item Env:SUPABASE_ACCESS_TOKEN -ErrorAction SilentlyContinue
}

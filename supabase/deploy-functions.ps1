# Deploy PalTuro Supabase Edge Functions using the PAT in palturo/.env.cli.
# Never put this PAT in .env / --dart-define; it is an account-level token.

$ErrorActionPreference = 'Stop'

$envFile = Join-Path (Split-Path -Parent $PSScriptRoot) '.env.cli'
if (-not (Test-Path $envFile)) {
    throw "Missing $envFile. Add SUPABASE_PAT to it first."
}

$pat = $null
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*SUPABASE_PAT\s*=\s*(.+?)\s*$') {
        $pat = $matches[1].Trim()
    }
}

if ([string]::IsNullOrWhiteSpace($pat) -or $pat -eq 'REPLACE_AND_ROTATE') {
    throw "Set a real SUPABASE_PAT in $envFile before deploying."
}

$env:SUPABASE_ACCESS_TOKEN = $pat
try {
    $projectRef = 'yjcrfgvenilptrnudvcb'
    $functions = @(
        'classify-skill',
        'generate-embeddings',
        'get-matches',
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

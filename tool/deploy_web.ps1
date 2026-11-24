# Build the Flutter web app, merge the auth pages, and deploy the Worker.
# Run from anywhere: powershell -ExecutionPolicy Bypass -File tool\deploy_web.ps1
$ErrorActionPreference = 'Stop'

$appRoot = Split-Path $PSScriptRoot -Parent
Set-Location $appRoot

# Production is main-only. The post-test-survey branch is for study runs and
# must never reach the live Worker. Set PALTURO_ALLOW_BRANCH_DEPLOY=1 only for
# an intentional non-main deployment.
$branch = (git rev-parse --abbrev-ref HEAD 2>$null)
if ($branch -and $branch -ne 'main' -and $env:PALTURO_ALLOW_BRANCH_DEPLOY -ne '1') {
  throw "Refusing to deploy '$branch'. Production deploys must run from main."
}

if (-not (Test-Path '.env.production')) {
  throw 'Missing .env.production (SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY).'
}

# Regenerate the static skills-exchange pages and sitemap before Flutter copies
# the web/ directory. These pages are real HTML and must exist in the build.
node tool\generate_seo_pages.js
if ($LASTEXITCODE -ne 0) {
  throw 'SEO page generation failed.'
}

flutter build web --release --dart-define-from-file=.env.production

$merged = Join-Path $appRoot 'build\web-merged'
if (Test-Path $merged) { Remove-Item $merged -Recurse -Force }
New-Item -ItemType Directory -Path $merged | Out-Null
Copy-Item 'build\web\*' $merged -Recurse -Force

# Stamp the build so the app can detect a new deploy and offer a reload.
$versionPath = Join-Path $merged 'version.json'
if (Test-Path $versionPath) {
  $version = Get-Content $versionPath -Raw | ConvertFrom-Json
  $version | Add-Member -NotePropertyName build `
    -NotePropertyValue ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) -Force
  $version | ConvertTo-Json -Compress | Set-Content $versionPath -Encoding utf8
}

$auth = Join-Path (Split-Path $appRoot -Parent) 'palturo-auth-web\public'
if (-not (Test-Path (Join-Path $auth 'index.html'))) {
  throw "Auth pages not found at $auth"
}

# Root assets referenced by the auth page with absolute URLs.
foreach ($file in @('app.js', 'config.js', 'styles.css')) {
  Copy-Item (Join-Path $auth $file) $merged -Force
}
New-Item -ItemType Directory -Path (Join-Path $merged 'vendor') -Force | Out-Null
Copy-Item (Join-Path $auth 'vendor\*') (Join-Path $merged 'vendor') -Recurse -Force
New-Item -ItemType Directory -Path (Join-Path $merged 'assets') -Force | Out-Null
Copy-Item (Join-Path $auth 'assets\*') (Join-Path $merged 'assets') -Recurse -Force

# Supabase email links point at /reset and /confirm.
foreach ($route in @('reset', 'confirm')) {
  $dir = Join-Path $merged $route
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  Copy-Item (Join-Path $auth 'index.html') (Join-Path $dir 'index.html') -Force
}

# The app CSP wins over the auth project's copy.
Copy-Item 'web\_headers' (Join-Path $merged '_headers') -Force

foreach ($route in @('reset', 'confirm')) {
  if (-not (Test-Path (Join-Path $merged "$route\index.html"))) {
    throw "Missing $route/index.html after merge."
  }
}

npx wrangler deploy --config cloudflare/wrangler.jsonc

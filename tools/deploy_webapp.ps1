#Requires -Version 5.1
<#
.SYNOPSIS
  Build and deploy the PalTuro cross-platform webapp to Vercel.
.DESCRIPTION
  Uses the same Flutter UI as the mobile app. The web build handles recovery
  links itself, so no browser password form is involved.

  One-time: npx vercel login
#>
param(
  [switch]$Preview
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".env.production")) {
  throw "Missing .env.production. It must contain SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and APP_PUBLIC_URL."
}

flutter build web --release `
  --dart-define-from-file=.env.production `
  --base-href /

if (Test-Path "web/vercel.json") {
  Copy-Item "web/vercel.json" "build/web/vercel.json" -Force
}

if ($Preview) {
  npx --yes vercel@latest deploy build/web
} else {
  npx --yes vercel@latest deploy build/web --prod
}

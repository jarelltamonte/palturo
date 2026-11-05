#Requires -Version 5.1
<#
.SYNOPSIS
  Build the PalTuro web app and deploy build/web to Vercel.
.DESCRIPTION
  Requires a one-time `npx vercel login`. The production URL is injected through
  .env.production so Supabase auth emails always return to https://palturo.app.
#>
param(
  [switch]$Preview
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".env.production")) {
  throw "Missing .env.production. Create it from .env.example and set APP_PUBLIC_URL=https://palturo.app."
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

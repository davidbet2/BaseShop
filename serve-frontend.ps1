# ─────────────────────────────────────────────────────────────
# BaseShop — Serve Flutter web build on http://localhost:8080
# Usage: .\serve-frontend.ps1
# ─────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$WebDir     = Join-Path $ScriptDir "frontend\build\web"
$Port       = 8080
$Flutter    = "C:\Users\david\flutter\bin\flutter.bat"

# Build if the web output doesn't exist
if (-Not (Test-Path (Join-Path $WebDir "index.html"))) {
    Write-Host "[serve-frontend] Build not found. Building now..."
    Push-Location (Join-Path $ScriptDir "frontend")
    & $Flutter build web
    Pop-Location
}

Write-Host "[serve-frontend] Serving $WebDir on http://localhost:$Port"
Write-Host "[serve-frontend] Press Ctrl+C to stop."

Set-Location $WebDir
npx --yes serve -s . -l $Port

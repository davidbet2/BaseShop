@echo off
REM ─────────────────────────────────────────────────────────────
REM BaseShop — Serve Flutter web build on http://localhost:8080
REM Doble clic o: serve-frontend.bat
REM ─────────────────────────────────────────────────────────────

set PORT=8080
set FLUTTER=C:\Users\david\flutter\bin\flutter.bat
set WEB_DIR=%~dp0frontend\build\web

IF NOT EXIST "%WEB_DIR%\index.html" (
    echo [serve-frontend] Build no encontrado. Compilando...
    cd /d "%~dp0frontend"
    call "%FLUTTER%" build web
)

echo [serve-frontend] Sirviendo en http://localhost:%PORT%
echo [serve-frontend] Ctrl+C para detener.
cd /d "%WEB_DIR%"
npx --yes serve -s . -l %PORT%

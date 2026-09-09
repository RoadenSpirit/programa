# Script de automatización de compilación con PyInstaller para Windows.
# Requisitos: Tener instalado Python en Windows y ejecutar este script en PowerShell.

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "       COMPILADOR DE SCRIPTS (PROCESADOR DE TOMOS) FOR WINDOWS    " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Validar instalación de PyInstaller
if (-not (Get-Command "pyinstaller" -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️ PyInstaller no está instalado. Instalándolo vía pip..." -ForegroundColor Yellow
    pip install pyinstaller
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error al instalar PyInstaller con pip. Asegúrate de tener Python y pip configurados en el PATH." -ForegroundColor Red
        exit 1
    }
}

# Carpetas de trabajo
$CurrentDir = Get-Location
$SourceDir = $CurrentDir
$OutDir = Join-Path $CurrentDir "dist_windows"

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

Write-Host "Compilando scripts desde: $SourceDir" -ForegroundColor Gray
Write-Host "Salida de los ejecutables: $OutDir" -ForegroundColor Gray

# Compilar _preparar_tomos.py
Write-Host "`n[1/3] Compilando _preparar_tomos..." -ForegroundColor Yellow
pyinstaller --onefile --console --clean --noconfirm --distpath $OutDir --workpath "$CurrentDir\build_win" --name _preparar_tomos _preparar_tomos.py

# Compilar _renombrar_folios.py
Write-Host "`n[2/3] Compilando _renombrar_folios..." -ForegroundColor Yellow
pyinstaller --onefile --console --clean --noconfirm --distpath $OutDir --workpath "$CurrentDir\build_win" --name _renombrar_folios _renombrar_folios.py

# Compilar _limpiar_tomos.py
Write-Host "`n[3/3] Compilando _limpiar_tomos..." -ForegroundColor Yellow
pyinstaller --onefile --console --clean --noconfirm --distpath $OutDir --workpath "$CurrentDir\build_win" --name _limpiar_tomos _limpiar_tomos.py

# Limpieza de carpetas temporales de compilación
Write-Host "`n🧹 Limpiando archivos temporales..." -ForegroundColor Gray
if (Test-Path "$CurrentDir\build_win") { Remove-Item -Recurse -Force "$CurrentDir\build_win" }
Get-ChildItem -Filter *.spec | Remove-Item -Force

Write-Host "`n=================================================================" -ForegroundColor Green
Write-Host "🎉 COMPILACIÓN TERMINADA CON ÉXITO!" -ForegroundColor Green
Write-Host "Los archivos ejecutables (.exe) se encuentran en la carpeta:" -ForegroundColor Green
Write-Host "   $OutDir" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green

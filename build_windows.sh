#!/usr/bin/env bash
# ==============================================================================
#   CONSTRUCTOR DE EJECUTABLES WINDOWS PARA PROCESADOR DE TOMOS
#   Requiere PyInstaller:
#      pip install pyinstaller
#   Genera output_win/ con los 3 ejecutables para Windows
#   (Los bins son Linux pero los .spec sirven de template para build en Win10)
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYSCRIPTS="$SCRIPT_DIR/programaPY"

echo "================================================================="
echo "   CONSTRUCTOR DE EJECUTABLES (Plantilla Cross-Platform)"
echo "================================================================="
echo "Instalando PyInstaller..."
python3 -m pip install pyinstaller --break-system-packages 1>/dev/null || true

echo "Limpiando builds anteriores..."
rm -rf dist_win build dist output_win
rm -f *.spec

echo "Construyendo _preparar_tomos..."
python3 -m PyInstaller.__main__ --onefile --console --clean --noconfirm \
    --name _preparar_tomos "$PYSCRIPTS/_preparar_tomos.py"

echo "Construyendo _renombrar_folios..."
python3 -m PyInstaller.__main__ --onefile --console --clean --noconfirm \
    --name _renombrar_folios "$PYSCRIPTS/_renombrar_folios.py"

echo "Construyendo _limpiar_tomos..."
python3 -m PyInstaller.__main__ --onefile --console --clean --noconfirm \
    --name _limpiar_tomos "$PYSCRIPTS/_limpiar_tomos.py"

echo "Organizando ejecutables..."
mkdir -p output_win
cp dist/_preparar_tomos output_win/
cp dist/_renombrar_folios output_win/
cp dist/_limpiar_tomos output_win/

echo "Limpiando..."
rm -rf dist build *.spec

echo "================================================================="
echo "   EJECUTABLES GENERADOS EN: output_win/"
echo "   Usa los scripts .spec para rebuilds en Windows"
echo "================================================================="

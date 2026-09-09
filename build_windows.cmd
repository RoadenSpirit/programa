@echo off
REM ==============================================================================
REM   CONSTRUCTOR DE EJECUTABLES WINDOWS PARA PROCESADOR DE TOMOS
REM   Requiere Python 3.11+ con PyInstaller previamente instalado:
REM      pip install pyinstaller
REM   Genera dist_win/ con los 3 ejecutables listos para usar juntos.
REM ==============================================================================
setlocal
set PYSCRIPTS=%~dp0programaPY

echo =================================================================
echo    CONSTRUCTOR DE EJECUTABLES WINDOWS
echo =================================================================
echo Instalando PyInstaller (omitir si ya esta instalado)...
pip install pyinstaller 1>nul 2>nul

echo Limpiando builds anteriores...
if exist dist_win rmdir /s /q dist_win
if exist build rmdir /s /q build
if exist *.spec del /q *.spec

echo Construyendo _preparar_tomos.exe ...
pyinstaller --onefile --console --clean --noconfirm --name _preparar_tomos "%PYSCRIPTS%\_preparar_tomos.py"
move /Y dist\_preparar_tomos.exe dist_win\_preparar_tomos.exe 1>nul 2>nul

echo Construyendo _renombrar_folios.exe ...
pyinstaller --onefile --console --clean --noconfirm --name _renombrar_folios "%PYSCRIPTS%\_renombrar_folios.py"
move /Y dist\_renombrar_folios.exe dist_win\_renombrar_folios.exe 1>nul 2>nul

echo Construyendo _limpiar_tomos.exe ...
pyinstaller --onefile --console --clean --noconfirm --name _limpiar_tomos "%PYSCRIPTS%\_limpiar_tomos.py"
move /Y dist\_limpiar_tomos.exe dist_win\_limpiar_tomos.exe 1>nul 2>nul

echo Limpiando archivos temporales...
if exist dist rmdir /s /q dist
if exist build rmdir /s /q build
if exist *.spec del /q *.spec

echo =================================================================
echo    EJECUTABLES GENERADOS EN: dist_win
echo    Usa dist_win\_preparar_tomos.exe desde la raiz de tus tomos
echo =================================================================
endlocal

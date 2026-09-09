@echo off
title Compilar Procesador de Tomos en Windows
echo =================================================================
echo        COMPILADOR DE SCRIPTS (PROCESADOR DE TOMOS) FOR WINDOWS
echo =================================================================
echo.
echo Verificando si PyInstaller esta instalado...
pyinstaller --version >nul 2>&1
if %errorlevel% neq 0 (
    echo PyInstaller no esta instalado. Intentando instalar con pip...
    pip install pyinstaller
    if %errorlevel% neq 0 (
        echo Error: No se pudo instalar PyInstaller. Asegurate de tener Python instalado y en el PATH.
        pause
        exit /b %errorlevel%
    )
)

echo.
echo Compilando _preparar_tomos.py...
pyinstaller --onefile --console --clean --noconfirm --name _preparar_tomos _preparar_tomos.py

echo.
echo Compilando _renombrar_folios.py...
pyinstaller --onefile --console --clean --noconfirm --name _renombrar_folios _renombrar_folios.py

echo.
echo Compilando _limpiar_tomos.py...
pyinstaller --onefile --console --clean --noconfirm --name _limpiar_tomos _limpiar_tomos.py

echo.
echo Limpiando archivos temporales...
if exist build rd /s /q build
del /f /q *.spec

echo.
echo =================================================================
echo 🎉 COMPILACION TERMINADA!
echo Los archivos .exe estan en la carpeta "dist".
echo Copialos a la raiz de tus tomos para comenzar a trabajar.
echo =================================================================
pause

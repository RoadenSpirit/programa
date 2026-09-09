#!/usr/bin/env python3
import os
import re
import sys
import shutil


def get_base_dir():
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))


RAIZ = get_base_dir()
IS_FROZEN = getattr(sys, 'frozen', False)
if IS_FROZEN:
    _EXT = ".exe" if sys.platform == "win32" else ""
    SCRIPT_CORE = os.path.join(RAIZ, "_renombrar_folios" + _EXT)
else:
    SCRIPT_CORE = os.path.join(RAIZ, "_renombrar_folios.py")
PATRON_TOMO = re.compile(r'^\s*tomo\s*\d+\s*$', re.IGNORECASE)
NOMBRE_CONFIG = "_configuracion.txt"


def plantilla_config():
    return """# CONFIGURACIÓN DEL TOMO
# FOLIOS_FALTANTES: Folios a saltar (ej: 15, 128-135, 200). Dejar vacío o 0 si no hay.
FOLIOS_FALTANTES =

# FOLIO_INICIAL: Folio con el que empieza el tomo (por defecto: 1).
FOLIO_INICIAL = 1

# TAMANO_MUESTRA: Frecuencia de imágenes para la carpeta 'test' (por defecto: 10).
TAMANO_MUESTRA = 10

# MODO_NUMERACION: SIMPLE (Folio 1, Folio 2) o SUBFOLIOS (Folio 1_1, Folio 1_2).
MODO_NUMERACION = SUBFOLIOS
"""


def carpetas_tomo():
    return sorted(
        d for d in os.listdir(RAIZ)
        if os.path.isdir(os.path.join(RAIZ, d)) and PATRON_TOMO.match(d)
    )


def preparar_tomo(nombre_tomo):
    ruta_tomo = os.path.join(RAIZ, nombre_tomo)
    estado = {'script': None, 'config': None, 'anexos': None}

    destino_script = os.path.join(ruta_tomo, os.path.basename(SCRIPT_CORE))
    try:
        shutil.copy2(SCRIPT_CORE, destino_script)
        estado['script'] = 'copiado'
    except OSError as e:
        estado['script'] = f'ERROR ({e})'

    # Eliminar viejo renombrar_folios.py sin guion si existe
    viejo_script = os.path.join(ruta_tomo, "renombrar_folios.py")
    if os.path.isfile(viejo_script):
        try:
            os.remove(viejo_script)
        except OSError:
            pass

    # Crear _configuracion.txt si no existe
    ruta_config = os.path.join(ruta_tomo, NOMBRE_CONFIG)
    if os.path.isfile(ruta_config):
        estado['config'] = 'ya existía'
    else:
        try:
            with open(ruta_config, "w", encoding="utf-8") as f:
                f.write(plantilla_config())
            estado['config'] = 'creado'
        except OSError as e:
            estado['config'] = f'ERROR ({e})'

    # Crear carpeta anexos
    carpeta_anexos = os.path.join(ruta_tomo, "anexos")
    if os.path.isdir(carpeta_anexos):
        estado['anexos'] = 'ya existía'
    else:
        try:
            os.makedirs(carpeta_anexos)
            estado['anexos'] = 'creada'
        except OSError as e:
            estado['anexos'] = f'ERROR ({e})'

    # Limpiar cualquier TXT legado (* - faltantes.txt, faltantes.txt o configuracion.txt sin guion)
    for entrada in os.listdir(ruta_tomo):
        if (entrada.lower().endswith(" - faltantes.txt")
                or entrada.lower() == "faltantes.txt"
                or entrada.lower() == "configuracion.txt"):
            try:
                os.remove(os.path.join(ruta_tomo, entrada))
            except OSError:
                pass

    return estado


def main():
    print("=================================================================")
    print("           PREPARADOR DE TOMOS (DESPLIEGUE MASIVO)                ")
    print("=================================================================")

    if not os.path.isfile(SCRIPT_CORE):
        print(f"❌ ERROR: No se encontró '{SCRIPT_CORE}'.")
        print("   Este script y '_renombrar_folios.exe' deben estar juntos en la raíz.")
        sys.exit(1)

    tomos = carpetas_tomo()
    if not tomos:
        print("⚠️ No se encontraron carpetas de tomos (patrón: 'tomo NÚMERO').")
        sys.exit(1)

    print(f"Tomos detectados: {len(tomos)}\n")

    errores = 0
    for nombre in tomos:
        estado = preparar_tomo(nombre)
        fallo = any(str(v).startswith('ERROR') for v in estado.values())
        if fallo:
            errores += 1
        print(f"📚 {nombre}")
        print(f"    · Script _renombrar_folios.py: {estado['script']}")
        print(f"    · BD '{NOMBRE_CONFIG}'        : {estado['config']}")
        print(f"    · Carpeta anexos/            : {estado['anexos']}")

    print()
    if errores:
        print(f"⚠️ Proceso terminado con {errores} tomo(s) con errores. Revisa arriba.")
        sys.exit(1)
    print("🎉 ¡TODOS LOS TOMOS QUEDARON PREPARADOS!")
    print("✏️  Siguiente paso: edita _configuracion.txt en cada tomo y ejecuta su script.")


if __name__ == "__main__":
    main()

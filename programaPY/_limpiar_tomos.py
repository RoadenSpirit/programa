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
PATRON_TOMO = re.compile(r'^\s*tomo\s*\d+\s*$', re.IGNORECASE)
EXTENSIONES_IMAGEN = ('.jpg', '.jpeg', '.png')
CONFIG_OFICIAL = "_configuracion.txt"
REPORTE_OFICIAL = "_folios faltantes.txt"

ARCHIVOS_A_BORRAR = [
    "_renombrar_folios.py", "_renombrar_folios.exe",
    "renombrar_folios.py", "renombrar_folios.exe",
    ".rename_history.json"
]
CARPETAS_A_BORRAR = ["test", "_duplicados"]


def tamano_ruta(ruta):
    if os.path.isfile(ruta):
        return os.path.getsize(ruta)
    total = 0
    for base, _, archivos in os.walk(ruta):
        for a in archivos:
            try:
                total += os.path.getsize(os.path.join(base, a))
            except OSError:
                pass
    return total


def carpetas_tomo():
    return sorted(
        d for d in os.listdir(RAIZ)
        if os.path.isdir(os.path.join(RAIZ, d)) and PATRON_TOMO.match(d)
    )


def recolectar_objetivos(ruta_tomo):
    objetivos = []
    for nombre in ARCHIVOS_A_BORRAR:
        ruta = os.path.join(ruta_tomo, nombre)
        if os.path.isfile(ruta):
            objetivos.append(('archivo', ruta, nombre))
    for nombre in CARPETAS_A_BORRAR:
        ruta = os.path.join(ruta_tomo, nombre)
        if os.path.isdir(ruta):
            objetivos.append(('carpeta', ruta, nombre + '/'))
    for entrada in os.listdir(ruta_tomo):
        ruta = os.path.join(ruta_tomo, entrada)
        if entrada.startswith('_temp_') and os.path.isfile(ruta):
            objetivos.append(('archivo', ruta, entrada))
        elif entrada.lower().endswith(" - faltantes.txt") and os.path.isfile(ruta):
            objetivos.append(('archivo', ruta, entrada))
        elif entrada.lower() in ("faltantes.txt", "configuracion.txt", "folios faltantes.txt") and os.path.isfile(ruta):
            objetivos.append(('archivo', ruta, entrada))
    return objetivos


def revisar_sobrantes(nombre_tomo, ruta_tomo):
    sobrantes = []
    for entrada in sorted(os.listdir(ruta_tomo)):
        ruta = os.path.join(ruta_tomo, entrada)
        if os.path.isdir(ruta):
            if entrada.lower() != 'anexos':
                sobrantes.append(f"carpeta no esperada: '{entrada}/'")
            continue
        if os.path.isfile(ruta):
            if (not entrada.lower().endswith(EXTENSIONES_IMAGEN)
                    and entrada != REPORTE_OFICIAL
                    and entrada != CONFIG_OFICIAL):
                sobrantes.append(f"archivo no esperado: '{entrada}'")
    return sobrantes


def main():
    print("=================================================================")
    print("         FINALIZADOR DE TOMOS (LIMPIEZA DE ENTREGA)               ")
    print("=================================================================")

    tomos = carpetas_tomo()
    if not tomos:
        print("⚠️ No se encontraron carpetas de tomos (patrón: 'tomo NÚMERO').")
        sys.exit(1)

    plan_por_tomo = {}
    total_bytes = 0
    total_elementos = 0
    for nombre in tomos:
        ruta_tomo = os.path.join(RAIZ, nombre)
        objetivos = recolectar_objetivos(ruta_tomo)
        bytes_tomo = sum(tamano_ruta(r) for _, r, _ in objetivos)
        if objetivos:
            plan_por_tomo[nombre] = objetivos
            total_bytes += bytes_tomo
            total_elementos += len(objetivos)

    if not plan_por_tomo:
        print("✅ No hay nada que limpiar: los tomos ya están finalizados.")
        sys.exit(0)

    print(f"Elementos a eliminar: {total_elementos} "
          f"(≈ {total_bytes / (1024 * 1024):.1f} MB liberados)\n")

    for nombre, objetivos in plan_por_tomo.items():
        print(f"📚 {nombre}")
        for tipo, _, etiqueta in objetivos:
            print(f"    · [{tipo}] {etiqueta}")

    if '--yes' not in sys.argv and '-y' not in sys.argv:
        print()
        respuesta = input("¿Confirmas la eliminación? Esta acción NO se puede deshacer [S/N]: ")
        if respuesta.strip().upper() != 'S':
            print("❌ Operación cancelada. No se borró nada.")
            sys.exit(0)

    print()
    errores = 0
    for nombre, objetivos in plan_por_tomo.items():
        for tipo, ruta, etiqueta in objetivos:
            try:
                if tipo == 'archivo':
                    os.remove(ruta)
                else:
                    shutil.rmtree(ruta)
                print(f" 🗑️ {nombre}: '{etiqueta}' eliminado.")
            except OSError as e:
                errores += 1
                print(f" ⚠️ {nombre}: no se pudo eliminar '{etiqueta}' ({e})")

    print()
    avisos = 0
    for nombre in tomos:
        sobrantes = revisar_sobrantes(nombre, os.path.join(RAIZ, nombre))
        if sobrantes:
            avisos += len(sobrantes)
            print(f" 👀 {nombre} (revisar manualmente):")
            for s in sobrantes:
                print(f"    · {s}")

    print()
    if errores:
        print(f"⚠️ Limpieza terminada con {errores} error(es).")
        sys.exit(1)
    print("🎉 ¡LIMPIEZA COMPLETADA!")
    print(f"📦 Los tomos conservan solo: imágenes 'Folio X.jpg', '{REPORTE_OFICIAL}', '{CONFIG_OFICIAL}' y carpeta 'anexos/'.")
    if avisos:
        print(f"👀 Ojo: hay {avisos} elemento(s) fuera de lo esperado que NO se tocaron.")


if __name__ == "__main__":
    main()

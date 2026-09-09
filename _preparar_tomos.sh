#!/usr/bin/env bash

# ==============================================================================
# PREPARADOR DE TOMOS (VERSIÓN BASH)
# ==============================================================================

CARPETA="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_CORE="$CARPETA/_renombrar_folios.sh"
NOMBRE_CONFIG="_configuracion.txt"

echo "================================================================="
echo "           PREPARADOR DE TOMOS (DESPLIEGUE MASIVO BASH)          "
echo "================================================================="

if [ ! -f "$SCRIPT_CORE" ]; then
    echo "❌ ERROR: No se encontró '$SCRIPT_CORE'."
    echo "   Este script y '_renombrar_folios.sh' deben estar juntos en la raíz."
    exit 1
fi

shopt -s nullglob nocasematch
tomos=()
for d in "$CARPETA"/*/; do
    b="$(basename "$d")"
    if [[ "$b" =~ ^tomo\ [0-9]+$ ]]; then
        tomos+=("$b")
    fi
done
shopt -u nullglob nocasematch

if [ ${#tomos[@]} -eq 0 ]; then
    echo "⚠️ No se encontraron carpetas de tomos (patrón: 'tomo NÚMERO')."
    exit 1
fi

echo "Tomos detectados: ${#tomos[@]}"
echo ""

plantilla_config() {
    cat <<'EOF'
# CONFIGURACIÓN DEL TOMO
# FOLIOS_FALTANTES: Folios a saltar (ej: 15, 128-135, 200). Dejar vacío o 0 si no hay.
FOLIOS_FALTANTES =

# FOLIO_INICIAL: Folio con el que empieza el tomo (por defecto: 1).
FOLIO_INICIAL = 1

# TAMANO_MUESTRA: Frecuencia de imágenes para la carpeta 'test' (por defecto: 10).
TAMANO_MUESTRA = 10

# MODO_NUMERACION: SIMPLE (Folio 1, Folio 2) o SUBFOLIOS (Folio 1_1, Folio 1_2).
MODO_NUMERACION = SUBFOLIOS
EOF
}

errores=0
for nombre in "${tomos[@]}"; do
    ruta_tomo="$CARPETA/$nombre"
    echo "📚 $nombre"

    # Copiar _renombrar_folios.sh
    if cp "$SCRIPT_CORE" "$ruta_tomo/_renombrar_folios.sh" 2>/dev/null && chmod +x "$ruta_tomo/_renombrar_folios.sh" 2>/dev/null; then
        echo "    · Script _renombrar_folios.sh: copiado"
    else
        echo "    · Script _renombrar_folios.sh: ERROR"
        errores=$((errores + 1))
    fi

    # Eliminar viejos scripts si existen
    rm -f "$ruta_tomo/renombrar_folios.sh" "$ruta_tomo/_renombrar_folios.py" "$ruta_tomo/renombrar_folios.py"

    # Crear _configuracion.txt si no existe
    ruta_cfg="$ruta_tomo/$NOMBRE_CONFIG"
    if [ -f "$ruta_cfg" ]; then
        echo "    · BD '$NOMBRE_CONFIG'       : ya existía"
    else
        if plantilla_config > "$ruta_cfg"; then
            echo "    · BD '$NOMBRE_CONFIG'       : creado"
        else
            echo "    · BD '$NOMBRE_CONFIG'       : ERROR"
            errores=$((errores + 1))
        fi
    fi

    # Crear carpeta anexos/
    if [ -d "$ruta_tomo/anexos" ]; then
        echo "    · Carpeta anexos/            : ya existía"
    else
        if mkdir -p "$ruta_tomo/anexos"; then
            echo "    · Carpeta anexos/            : creada"
        else
            echo "    · Carpeta anexos/            : ERROR"
            errores=$((errores + 1))
        fi
    fi

    # Limpiar cualquier TXT legado
    shopt -s nullglob nocasematch
    for f in "$ruta_tomo"/*; do
        b="$(basename "$f")"
        if [[ "$b" =~ \ -\ faltantes\.txt$ ]] || [ "$b" = "faltantes.txt" ] || [ "$b" = "configuracion.txt" ]; then
            rm -f "$f"
        fi
    done
    shopt -u nullglob nocaseglob
done

echo ""
if [ $errores -gt 0 ]; then
    echo "⚠️ Proceso terminado con $errores tomo(s) con errores. Revisa arriba."
    exit 1
fi
echo "🎉 ¡TODOS LOS TOMOS QUEDARON PREPARADOS!"
echo "✏️  Siguiente paso: edita _configuracion.txt en cada tomo y ejecuta su script."

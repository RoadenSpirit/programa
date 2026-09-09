#!/usr/bin/env bash

# ==============================================================================
# CONFIGURACIÓN DEL SCRIPT (BASH)
# ==============================================================================

# Lista de números de folios que FALTAN y deben ser SALTADOS.
# Ejemplo sin folios faltantes:  FOLIOS_A_SALTAR=()
# Ejemplo con folios faltantes: FOLIOS_A_SALTAR=(128 129)
FOLIOS_A_SALTAR=()

# Tamaño del intervalo para tomar muestras de control (carpeta 'test')
TAMANO_MUESTRA=50

# Número de folio inicial de la secuencia
FOLIO_INICIAL=1

# Nombres de archivos y carpetas de salida
NOMBRE_REPORTE="faltantes.txt"
NOMBRE_CARPETA_TEST="test"

# Obtener la carpeta donde se encuentra este script
CARPETA="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$CARPETA" || exit 1

# ==============================================================================
# FUNCIONES AUXILIARES
# ==============================================================================

# Función para calcular Hash SHA-256 o MD5 según disponibilidad
calcular_hash() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v md5sum >/dev/null 2>&1; then
        md5sum "$1" | awk '{print $1}'
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q "$1"
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        # Si no hay herramienta de hash, usar tamaño de archivo como fallback
        wc -c < "$1" | awk '{print $1}'
    fi
}

# Extraer número del nombre para ordenar numéricamente
extraer_numero() {
    local num
    num=$(echo "$1" | grep -o -E '[0-9]+' | head -n 1)
    if [ -n "$num" ]; then
        echo "$num"
    else
        echo "999999"
    fi
}

# ==============================================================================
# PROCESO PRINCIPAL
# ==============================================================================

echo "================================================================="
echo "        PROCESADOR INTEGRAL DE TOMOS Y FOLIOS (VERSIÓN BASH)      "
echo "================================================================="
echo "Carpeta: $CARPETA"
echo "Folios a omitir: ${FOLIOS_A_SALTAR[*]:-Ninguno}"
echo "Tamaño de muestra configurado: Cada $TAMANO_MUESTRA folios"

# Buscar imágenes (.jpg, .jpeg, .png) ignorando _temp_
shopt -s nullglob nocaseglob
archivos=( *.jpg *.jpeg *.png )
shopt -u nullglob nocaseglob

# Filtrar archivos temporales
archivos_validos=()
for f in "${archivos[@]}"; do
    if [[ "$f" != _temp_* ]]; then
        archivos_validos+=("$f")
    fi
done

if [ ${#archivos_validos[@]} -eq 0 ]; then
    echo "⚠️ No se encontraron imágenes en la carpeta: $CARPETA"
    exit 0
fi

echo "Total imágenes iniciales: ${#archivos_validos[@]}"
echo ""

# Ordenar archivos numéricamente por su nombre actual
sorted_archivos=$(
    for f in "${archivos_validos[@]}"; do
        n=$(extraer_numero "$f")
        printf "%010d\t%s\n" "$n" "$f"
    done | sort -n -k1,1 | cut -f2-
)

# --------------------------------------------------------------------------
# ETAPA 1: DETECTAR Y ELIMINAR DUPLICADOS
# --------------------------------------------------------------------------
echo "--- 1. ELIMINANDO IMÁGENES DUPLICADAS ---"

declare -A hashes_vistos
archivos_unicos=()
duplicados_detectados=()

while IFS= read -r f; do
    [ -z "$f" ] && continue
    h=$(calcular_hash "$f")
    if [ -n "${hashes_vistos[$h]}" ]; then
        orig="${hashes_vistos[$h]}"
        duplicados_detectados+=("$f|$orig")
        rm -f "$f"
        echo " 🗑️ Duplicado eliminado: '$f' (Idéntica a '$orig')"
    else
        hashes_vistos[$h]="$f"
        archivos_unicos+=("$f")
    fi
done <<< "$sorted_archivos"

if [ ${#duplicados_detectados[@]} -eq 0 ]; then
    echo "✅ No se encontraron imágenes duplicadas."
fi

echo "Total imágenes únicas a organizar: ${#archivos_unicos[@]}"
echo ""

# --------------------------------------------------------------------------
# ETAPA 2: RENOMBRADO SECUENCIAL APLICANDO SALTOS
# --------------------------------------------------------------------------
echo "--- 2. RENOMBRANDO IMÁGENES ---"

# Crear función de verificación de saltos
es_folio_a_saltar() {
    local target=$1
    for s in "${FOLIOS_A_SALTAR[@]}"; do
        if [ "$s" -eq "$target" ]; then
            return 0
        fi
    done
    return 1
}

plan_orig=()
plan_nuevo=()
folio_actual=$FOLIO_INICIAL

for f in "${archivos_unicos[@]}"; do
    while es_folio_a_saltar "$folio_actual"; do
        echo " ⏩ Salto aplicado: Folio $folio_actual omitido por estar en la lista de faltantes."
        folio_actual=$((folio_actual + 1))
    done
    
    nuevo_nombre="Folio ${folio_actual}.jpg"
    plan_orig+=("$f")
    plan_nuevo+=("$nuevo_nombre")
    folio_actual=$((folio_actual + 1))
done

ultimo_folio_generado=$((folio_actual - 1))

# Renombrado en 2 fases con nombres temporales neutros
temporales=()
for i in "${!plan_orig[@]}"; do
    orig="${plan_orig[$i]}"
    nuevo="${plan_nuevo[$i]}"
    if [ "$orig" != "$nuevo" ]; then
        temp_name="_temp_rename_${i}_${orig}"
        mv -f "$orig" "$temp_name"
        temporales+=("$temp_name|$nuevo")
    else
        temporales+=("$orig|$nuevo")
    fi
done

for pair in "${temporales[@]}"; do
    temp_path="${pair%%|*}"
    final_path="${pair##*|}"
    if [ "$temp_path" != "$final_path" ] && [ -e "$temp_path" ]; then
        mv -f "$temp_path" "$final_path"
    fi
done

echo "✅ Renombrado completado."

# --------------------------------------------------------------------------
# ETAPA 3: REGENERACIÓN DE REPORTES FALTANTES.TXT
# --------------------------------------------------------------------------
rm -f "$NOMBRE_REPORTE"

{
    echo "========================================================="
    echo "            REPORTE DE CONTROL DE FOLIOS                 "
    echo "========================================================="
    echo "Total imágenes útiles  : ${#archivos_unicos[@]}"
    echo "Rango asignado         : Folio $FOLIO_INICIAL al Folio $ultimo_folio_generado"
    echo ""
    echo "---------------------------------------------------------"
    echo "FOLIOS FALTANTES / OMITIDOS:"
    echo "---------------------------------------------------------"

    if [ ${#FOLIOS_A_SALTAR[@]} -gt 0 ]; then
        echo "Total de folios omitidos : ${#FOLIOS_A_SALTAR[@]}"
        faltantes_str=""
        for s in "${FOLIOS_A_SALTAR[@]}"; do
            if [ -z "$faltantes_str" ]; then
                faltantes_str="Folio $s"
            else
                faltantes_str="$faltantes_str, Folio $s"
            fi
        done
        echo "Lista de folios faltantes : $faltantes_str"
        echo ""
    else
        echo "No se omitió ningún folio (Secuencia 100% continua)."
        echo ""
    fi

    if [ ${#duplicados_detectados[@]} -gt 0 ]; then
        echo "---------------------------------------------------------"
        echo "IMÁGENES DUPLICADAS ELIMINADAS:"
        echo "---------------------------------------------------------"
        echo "Total duplicados eliminados : ${#duplicados_detectados[@]}"
        for d in "${duplicados_detectados[@]}"; do
            dup_file="${d%%|*}"
            orig_file="${d##*|}"
            echo " - Archivo: '$dup_file' (Idéntica a '$orig_file')"
        done
    fi
} > "$NOMBRE_REPORTE"

echo "📄 Reporte '$NOMBRE_REPORTE' generado."

# --------------------------------------------------------------------------
# ETAPA 4: GENERACIÓN DE LA CARPETA TEST DE MUESTRAS
# --------------------------------------------------------------------------
echo "--- 3. CREANDO MUESTRAS DE CONTROL ---"

rm -rf "$NOMBRE_CARPETA_TEST"
mkdir -p "$NOMBRE_CARPETA_TEST"

count=${#plan_nuevo[@]}
intervalo=$TAMANO_MUESTRA
[ "$intervalo" -le 0 ] && intervalo=50

muestras_tomadas=0
for i in "${!plan_nuevo[@]}"; do
    idx=$((i + 1))
    nombre="${plan_nuevo[$i]}"
    if [ $((idx % intervalo)) -eq 0 ] || [ "$idx" -eq "$count" ]; then
        if [ -f "$nombre" ]; then
            cp -f "$nombre" "$NOMBRE_CARPETA_TEST/$nombre"
            muestras_tomadas=$((muestras_tomadas + 1))
        fi
    fi
done

echo "📂 Carpeta '$NOMBRE_CARPETA_TEST/' creada con éxito ($muestras_tomadas imágenes de muestra)."
echo ""
echo "🎉 ¡PROCESO FINALIZADO EXITOSAMENTE!"

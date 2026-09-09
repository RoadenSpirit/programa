#!/usr/bin/env bash

# ==============================================================================
# PROCESADOR INTEGRAL DE TOMOS Y FOLIOS (VERSIÓN BASH)
# ==============================================================================

CARPETA="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOMBRE_TOMO="$(basename "$CARPETA")"

NOMBRE_CONFIG="_configuracion.txt"
NOMBRE_REPORTE="_folios faltantes.txt"
NOMBRE_CARPETA_TEST="test"
NOMBRE_CARPETA_DUP="_duplicados"

FOLIO_INICIAL_DEFECTO=1
TAMANO_MUESTRA_DEFECTO=10
UMBRAL_SOSPECHOSO=2048

# ------------------------------------------------------------------------------
# FUNCIONES AUXILIARES
# ------------------------------------------------------------------------------

calcular_hash() {
    local archivo="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$archivo" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$archivo" | awk '{print $1}'
    elif command -v md5sum >/dev/null 2>&1; then
        md5sum "$archivo" | awk '{print $1}'
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q "$archivo"
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$archivo" | awk '{print $NF}'
    else
        wc -c < "$archivo" | awk '{print $1}'
    fi
}

extraer_numero() {
    local nombre="$1"
    local sin_ext="${nombre%.*}"
    local num
    num=$(echo "$sin_ext" | grep -o -E '[0-9]+' | head -n 1)
    if [ -n "$num" ]; then
        echo "$((10#$num))"
    else
        echo ""
    fi
}

formatear_rangos() {
    local nums=("$@")
    [ ${#nums[@]} -eq 0 ] && return
    
    IFS=$'\n' sorted=($(sort -n <<<"${nums[*]}"))
    unset IFS

    local res=""
    local i=0
    local n=${#sorted[@]}
    while [ $i -lt $n ]; do
        local inicio=${sorted[$i]}
        local fin=$inicio
        while [ $((i + 1)) -lt $n ] && [ ${sorted[$((i + 1))]} -eq $((fin + 1)) ]; do
            i=$((i + 1))
            fin=${sorted[$i]}
        done
        if [ $inicio -eq $fin ]; then
            chunk="$inicio"
        else
            chunk="${inicio}-${fin}"
        fi
        if [ -z "$res" ]; then
            res="$chunk"
        else
            res="${res}, ${chunk}"
        fi
        i=$((i + 1))
    done
    echo "$res"
}

# ------------------------------------------------------------------------------
# LECTURA DE CONFIGURACIÓN
# ------------------------------------------------------------------------------

ruta_config() {
    if [ -f "$CARPETA/$NOMBRE_CONFIG" ]; then
        echo "$CARPETA/$NOMBRE_CONFIG"
        return
    fi
    shopt -s nullglob nocaseglob
    for f in "$CARPETA"/*; do
        b="$(basename "$f")"
        if [ "$b" = "configuracion.txt" ] || [[ "$b" =~ \ -\ faltantes\.txt$ ]]; then
            echo "$f"
            shopt -u nullglob nocaseglob
            return
        fi
    done
    shopt -u nullglob nocaseglob
    echo ""
}

FOLIOS_FALTANTES_DECLARADOS=()
FOLIO_INICIAL=$FOLIO_INICIAL_DEFECTO
TAMANO_MUESTRA=$TAMANO_MUESTRA_DEFECTO
MODO_NUMERACION="SUBFOLIOS"

RUTA_CFG="$(ruta_config)"

if [ -z "$RUTA_CFG" ]; then
    RUTA_CFG="$CARPETA/$NOMBRE_CONFIG"
    cat <<'EOF' > "$RUTA_CFG"
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
    echo "================================================================="
    echo "              PROCESADOR INTEGRAL DE TOMOS Y FOLIOS               "
    echo "================================================================="
    echo "⚠️ Se ha creado la plantilla '$NOMBRE_CONFIG'."
    echo "✏️  Edítalo si necesitas cambiar la configuración y vuelve a ejecutar."
    exit 1
fi

while IFS= read -r linea || [ -n "$linea" ]; do
    limpia=$(echo "$linea" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -z "$limpia" || "$limpia" == \#* || "$limpia" != *"="* ]] && continue
    
    clave=$(echo "${limpia%%=*}" | tr '[:lower:]' '[:upper:]' | xargs)
    valor=$(echo "${limpia#*=}" | xargs)

    case "$clave" in
        FOLIOS_FALTANTES|FOLIOS_A_SALTAR)
            IFS=', ;' read -ra tokens <<< "$valor"
            for t in "${tokens[@]}"; do
                [ -z "$t" ] && continue
                if [[ "$t" =~ ^([0-9]+)[-–]([0-9]+)$ ]]; then
                    a=${BASH_REMATCH[1]}
                    b=${BASH_REMATCH[2]}
                    [ $a -gt $b ] && { tmp=$a; a=$b; b=$tmp; }
                    for ((k=a; k<=b; k++)); do
                        FOLIOS_FALTANTES_DECLARADOS+=("$k")
                    done
                elif [[ "$t" =~ ^[0-9]+$ ]]; then
                    [ "$t" -ne 0 ] && FOLIOS_FALTANTES_DECLARADOS+=("$t")
                fi
            done
            ;;
        FOLIO_INICIAL)
            if [[ "$valor" =~ ^[0-9]+$ ]] && [ "$valor" -ge 1 ]; then
                FOLIO_INICIAL="$valor"
            fi
            ;;
        TAMANO_MUESTRA)
            if [[ "$valor" =~ ^[0-9]+$ ]] && [ "$valor" -ge 1 ]; then
                TAMANO_MUESTRA="$valor"
            fi
            ;;
        MODO_NUMERACION)
            v_norm=$(echo "$valor" | tr '[:lower:]' '[:upper:]' | sed 's/[[:space:]_-]//g')
            if [[ "$v_norm" == "SUBFOLIOS" || "$v_norm" == "SUBFOLIO" ]]; then
                MODO_NUMERACION="SUBFOLIOS"
            elif [[ "$v_norm" == "SIMPLE" || "$v_norm" == "NORMAL" || "$v_norm" == "CLASICO" ]]; then
                MODO_NUMERACION="SIMPLE"
            fi
            ;;
    esac
done < "$RUTA_CFG"

if [ ${#FOLIOS_FALTANTES_DECLARADOS[@]} -gt 0 ]; then
    IFS=$'\n' FOLIOS_FALTANTES_DECLARADOS=($(sort -n -u <<<"${FOLIOS_FALTANTES_DECLARADOS[*]}"))
    unset IFS
fi

echo "================================================================="
echo "              PROCESADOR INTEGRAL DE TOMOS Y FOLIOS               "
echo "================================================================="
echo "Tomo      : $NOMBRE_TOMO"
echo "Config BD : $(basename "$RUTA_CFG")"
echo "Modo de numeración       : $MODO_NUMERACION"
echo "Folios omitidos declarados (${#FOLIOS_FALTANTES_DECLARADOS[@]}): $(formatear_rangos "${FOLIOS_FALTANTES_DECLARADOS[@]}")"
[ ${#FOLIOS_FALTANTES_DECLARADOS[@]} -eq 0 ] && echo " (Ninguno)"
echo "Muestras de control: cada $TAMANO_MUESTRA folios"

shopt -s nullglob nocaseglob
archivos=()
for f in "$CARPETA"/*; do
    [ -f "$f" ] || continue
    b="$(basename "$f")"
    [[ "$b" == _temp_* || "$b" == .* ]] && continue
    ext="${b##*.}"
    if [[ "$ext" =~ ^(jpg|jpeg|png)$ ]]; then
        archivos+=("$b")
    fi
done
shopt -u nullglob nocaseglob

if [ ${#archivos[@]} -eq 0 ]; then
    echo "⚠️ No se encontraron imágenes en la carpeta: $CARPETA"
    exit 1
fi

echo "Total imágenes iniciales: ${#archivos[@]}"
echo ""

ordenar_archivos() {
    for f in "$@"; do
        n=$(extraer_numero "$f")
        if [ -n "$n" ]; then
            printf "%010d\t%s\n" "$n" "$f"
        else
            printf "%010d\t%s\n" 9999999999 "$f"
        fi
    done | sort -n -k1,1 -k2,2 | cut -f2-
}

sorted_archivos=$(ordenar_archivos "${archivos[@]}")
IFS=$'\n' read -rd '' -a archivos_ordenados <<< "$sorted_archivos"
unset IFS

# ------------------------------------------------------------------------------
# ETAPA 1: ANOMALÍAS
# ------------------------------------------------------------------------------
echo "--- 1. ANALIZANDO ANOMALÍAS EN LOS ORIGINALES ---"
saltos_origen=()
sospechosos=()
sin_numero=()

prev_num=""
prev_file=""
for f in "${archivos_ordenados[@]}"; do
    size=$(wc -c < "$CARPETA/$f" | awk '{print $1}')
    if [ "$size" -lt $UMBRAL_SOSPECHOSO ]; then
        sospechosos+=("$f")
    fi
    
    num=$(extraer_numero "$f")
    if [ -z "$num" ]; then
        sin_numero+=("$f")
    else
        if [ -n "$prev_num" ] && [ $num -gt $((prev_num + 1)) ]; then
            diff=$((num - prev_num - 1))
            saltos_origen+=("$prev_file|$f|$diff")
        fi
        prev_num=$num
        prev_file=$f
    fi
done

if [ ${#saltos_origen[@]} -gt 0 ]; then
    echo " ⚠️ Saltos detectados en la secuencia original:"
    for s in "${saltos_origen[@]}"; do
        p1="${s%%|*}"
        rest="${s#*|}"
        p2="${rest%%|*}"
        diff="${rest#*|}"
        echo "    · Entre '$p1' y '$p2' faltan $diff números."
    done
else
    echo " ✅ Secuencia original continua."
fi

if [ ${#sospechosos[@]} -gt 0 ]; then
    echo " ⚠️ Archivos sospechosos (<$UMBRAL_SOSPECHOSO bytes): ${sospechosos[*]}"
fi
if [ ${#sin_numero[@]} -gt 0 ]; then
    echo " ⚠️ Archivos sin número en el nombre: ${sin_numero[*]}"
fi
echo ""

# ------------------------------------------------------------------------------
# ETAPA 2: DUPLICADOS -> _duplicados/
# ------------------------------------------------------------------------------
echo "--- 2. DUPLICADOS -> CARPETA '_duplicados/' ---"
declare -A hashes_vistos
archivos_unicos=()
duplicados_detectados=()

for f in "${archivos_ordenados[@]}"; do
    h=$(calcular_hash "$CARPETA/$f")
    if [ -n "${hashes_vistos[$h]}" ]; then
        orig="${hashes_vistos[$h]}"
        duplicados_detectados+=("$f|$orig")
    else
        hashes_vistos[$h]="$f"
        archivos_unicos+=("$f")
    fi
done

if [ ${#duplicados_detectados[@]} -gt 0 ]; then
    mkdir -p "$CARPETA/$NOMBRE_CARPETA_DUP"
    for dup_pair in "${duplicados_detectados[@]}"; do
        dup="${dup_pair%%|*}"
        orig="${dup_pair#*|}"
        dest="$CARPETA/$NOMBRE_CARPETA_DUP/$dup"
        if [ -e "$dest" ]; then
            base="${dup%.*}"
            ext="${dup##*.}"
            k=2
            while [ -e "$CARPETA/$NOMBRE_CARPETA_DUP/${base}_repetido_${k}.${ext}" ]; do
                k=$((k + 1))
            done
            dest="$CARPETA/$NOMBRE_CARPETA_DUP/${base}_repetido_${k}.${ext}"
        fi
        mv "$CARPETA/$dup" "$dest"
        echo " 📦 Movido a '$NOMBRE_CARPETA_DUP/': '$dup' (Idéntica a '$orig')"
    done
else
    echo "✅ No se encontraron imágenes duplicadas."
fi

echo "Total imágenes únicas a organizar: ${#archivos_unicos[@]}"
echo ""

# ------------------------------------------------------------------------------
# ETAPA 3: RENOMBRADO PROGRESIVO
# ------------------------------------------------------------------------------
echo "--- 3. RENOMBRADO PROGRESIVO ---"

es_primera_ejecucion=1
for f in "${archivos_unicos[@]}"; do
    if [[ "$f" =~ ^Folio\  ]]; then
        es_primera_ejecucion=0
        break
    fi
done

esta_bd_vacia=0
[ ${#FOLIOS_FALTANTES_DECLARADOS[@]} -eq 0 ] && esta_bd_vacia=1

numeros_unicos=()
for f in "${archivos_unicos[@]}"; do
    n=$(extraer_numero "$f")
    [ -n "$n" ] && numeros_unicos+=("$n")
done

faltantes_detectados=()
if [ ${#numeros_unicos[@]} -gt 1 ]; then
    if [ "$MODO_NUMERACION" = "SUBFOLIOS" ]; then
        implicitos=()
        for n in "${numeros_unicos[@]}"; do
            implicitos+=("$(((n + 1) / 2))")
        done
        IFS=$'\n' imp_sorted=($(sort -n -u <<<"${implicitos[*]}"))
        unset IFS
        for ((i=0; i<${#imp_sorted[@]}-1; i++)); do
            curr=${imp_sorted[$i]}
            next=${imp_sorted[$((i+1))]}
            if [ $next -gt $((curr + 1)) ]; then
                for ((k=curr+1; k<next; k++)); do
                    faltantes_detectados+=("$k")
                done
            fi
        done
    else
        IFS=$'\n' num_sorted=($(sort -n -u <<<"${numeros_unicos[*]}"))
        unset IFS
        for ((i=0; i<${#num_sorted[@]}-1; i++)); do
            curr=${num_sorted[$i]}
            next=${num_sorted[$((i+1))]}
            if [ $next -gt $((curr + 1)) ]; then
                for ((k=curr+1; k<next; k++)); do
                    faltantes_detectados+=("$k")
                done
            fi
        done
    fi
fi

faltantes_totales=()
if [ $es_primera_ejecucion -eq 1 ] && [ $esta_bd_vacia -eq 1 ] && [ ${#faltantes_detectados[@]} -gt 0 ]; then
    faltantes_totales=("${faltantes_detectados[@]}")
    str_rangos=$(formatear_rangos "${faltantes_detectados[@]}")
    sed -i "s/^[[:space:]]*FOLIOS_FALTANTES[[:space:]]*=.*/FOLIOS_FALTANTES = $str_rangos/" "$RUTA_CFG"
    echo " 📝 BD inicializada automáticamente con los saltos del escáner: $str_rangos"
else
    faltantes_totales=("${FOLIOS_FALTANTES_DECLARADOS[@]}")
fi

es_folio_omitido() {
    local target=$1
    for s in "${faltantes_totales[@]}"; do
        [ "$s" -eq "$target" ] && return 0
    done
    return 1
}

plan_orig=()
plan_nuevo=()
asignados=()
subfolios_count=0

if [ "$MODO_NUMERACION" = "SUBFOLIOS" ]; then
    folio_base=$FOLIO_INICIAL
    sub_idx=1
    for f in "${archivos_unicos[@]}"; do
        while es_folio_omitido "$folio_base"; do
            folio_base=$((folio_base + 1))
            sub_idx=1
        done
        nuevo="Folio ${folio_base}_${sub_idx}.jpg"
        plan_orig+=("$f")
        plan_nuevo+=("$nuevo")
        asignados+=("$folio_base")
        subfolios_count=$((subfolios_count + 1))

        if [ $sub_idx -eq 1 ]; then
            sub_idx=2
        else
            sub_idx=1
            folio_base=$((folio_base + 1))
        fi
    done
else
    folio_actual=$FOLIO_INICIAL
    for f in "${archivos_unicos[@]}"; do
        while es_folio_omitido "$folio_actual"; do
            folio_actual=$((folio_actual + 1))
        done
        nuevo="Folio ${folio_actual}.jpg"
        plan_orig+=("$f")
        plan_nuevo+=("$nuevo")
        asignados+=("$folio_actual")
        folio_actual=$((folio_actual + 1))
    done
fi

ultimo_folio=$FOLIO_INICIAL
for a in "${asignados[@]}"; do
    [ $a -gt $ultimo_folio ] && ultimo_folio=$a
done

temporales=()
for i in "${!plan_orig[@]}"; do
    orig="${plan_orig[$i]}"
    nuevo="${plan_nuevo[$i]}"
    if [ "$orig" != "$nuevo" ]; then
        temp="_temp_rename_${i}_${orig}"
        mv "$CARPETA/$orig" "$CARPETA/$temp"
        temporales+=("$temp|$nuevo")
    else
        temporales+=("$orig|$nuevo")
    fi
done

for pair in "${temporales[@]}"; do
    t_path="${pair%%|*}"
    f_path="${pair#*|}"
    if [ "$t_path" != "$f_path" ] && [ -e "$CARPETA/$t_path" ]; then
        mv "$CARPETA/$t_path" "$CARPETA/$f_path"
    fi
done

echo " ✅ Modo SUBFOLIOS: jerarquía conservada ($subfolios_count sub-folios tipo 'Folio X_1.jpg', 'Folio X_2.jpg')."
echo " ✅ Renombrado completado: Folio $FOLIO_INICIAL al Folio $ultimo_folio."
echo ""

# ------------------------------------------------------------------------------
# ETAPA 4: REPORTE _folios faltantes.txt
# ------------------------------------------------------------------------------
echo "--- 4. GENERANDO REPORTE '$NOMBRE_REPORTE' ---"
{
    echo "========================================================="
    echo "            REPORTE DE CONTROL DE FOLIOS                 "
    echo "========================================================="
    echo "Tomo                  : $NOMBRE_TOMO"
    echo "Modo de numeración    : $MODO_NUMERACION"
    echo "Total imágenes útiles : ${#archivos_unicos[@]}"
    echo "Rango asignado        : Folio $FOLIO_INICIAL al Folio $ultimo_folio"
    [ $subfolios_count -gt 0 ] && echo "Sub-folios (X_1, X_2) : $subfolios_count"
    echo ""
    echo "---------------------------------------------------------"
    echo "FOLIOS FALTANTES / OMITIDOS:"
    echo "---------------------------------------------------------"
    if [ ${#faltantes_totales[@]} -gt 0 ]; then
        echo "Total omitidos : ${#faltantes_totales[@]} (Folios: $(formatear_rangos "${faltantes_totales[@]}"))"
        if [ $es_primera_ejecucion -eq 1 ] && [ $esta_bd_vacia -eq 1 ] && [ ${#faltantes_detectados[@]} -gt 0 ]; then
            echo "Auto-detectados por saltos del escáner: $(formatear_rangos "${faltantes_detectados[@]}")"
        fi
        echo ""
    else
        echo "No se omitió ningún folio (Secuencia 100% continua)."
        echo ""
    fi

    if [ ${#duplicados_detectados[@]} -gt 0 ]; then
        echo "---------------------------------------------------------"
        echo "IMÁGENES DUPLICADAS MOVIDAS A '$NOMBRE_CARPETA_DUP/':"
        echo "---------------------------------------------------------"
        echo "Total duplicados movidos : ${#duplicados_detectados[@]}"
        for d in "${duplicados_detectados[@]}"; do
            dup="${d%%|*}"
            orig="${d#*|}"
            echo " - Archivo: '$dup' (Idéntica a '$orig')"
        done
        echo ""
    fi

    if [ ${#saltos_origen[@]} -gt 0 ] || [ ${#sospechosos[@]} -gt 0 ] || [ ${#sin_numero[@]} -gt 0 ]; then
        echo "---------------------------------------------------------"
        echo "ANOMALÍAS DETECTADAS EN ARCHIVOS ORIGINALES:"
        echo "---------------------------------------------------------"
        for s in "${saltos_origen[@]}"; do
            p1="${s%%|*}"
            rest="${s#*|}"
            p2="${rest%%|*}"
            diff="${rest#*|}"
            echo " - Salto en secuencia original: entre '$p1' y '$p2' faltan $diff números."
        done
        for s in "${sospechosos[@]}"; do
            echo " - Archivo sospechoso (<$UMBRAL_SOSPECHOSO bytes): '$s'"
        done
        for s in "${sin_numero[@]}"; do
            echo " - Archivo sin número en el nombre: '$s'"
        done
        echo ""
    fi
} > "$CARPETA/$NOMBRE_REPORTE"

echo "📄 Reporte '$NOMBRE_REPORTE' generado."
echo ""

# ------------------------------------------------------------------------------
# ETAPA 5: MUESTRAS test/
# ------------------------------------------------------------------------------
echo "--- 5. CREANDO MUESTRAS DE CONTROL 'test/' ---"
rm -rf "$CARPETA/$NOMBRE_CARPETA_TEST"
mkdir -p "$CARPETA/$NOMBRE_CARPETA_TEST"

IFS=$'\n' bases_unicas=($(sort -n -u <<<"${asignados[*]}"))
unset IFS

muestras_tomadas=0
total_bases=${#bases_unicas[@]}

for i in "${!bases_unicas[@]}"; do
    idx=$((i + 1))
    base="${bases_unicas[$i]}"
    if [ $((idx % TAMANO_MUESTRA)) -eq 0 ] || [ "$idx" -eq "$total_bases" ]; then
        for f in "$CARPETA"/Folio\ ${base}.jpg "$CARPETA"/Folio\ ${base}_*.jpg; do
            if [ -f "$f" ]; then
                cp -f "$f" "$CARPETA/$NOMBRE_CARPETA_TEST/$(basename "$f")"
                muestras_tomadas=$((muestras_tomadas + 1))
            fi
        done
    fi
done

echo "📂 Carpeta '$NOMBRE_CARPETA_TEST/' creada ($muestras_tomadas de ${#plan_nuevo[@]} imágenes de muestra)."
echo ""
echo "🎉 ¡PROCESO FINALIZADO EXITOSAMENTE!"

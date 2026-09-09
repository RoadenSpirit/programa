#!/usr/bin/env bash

# ==============================================================================
# FINALIZADOR DE TOMOS (VERSIÓN BASH)
# ==============================================================================

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_OFICIAL="_configuracion.txt"
REPORTE_OFICIAL="_folios faltantes.txt"

echo "================================================================="
echo "         FINALIZADOR DE TOMOS (LIMPIEZA DE ENTREGA BASH)          "
echo "================================================================="

shopt -s nullglob nocasematch
tomos=()
for d in "$RAIZ"/*/; do
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

recolectar_objetivos() {
    local ruta_tomo="$1"
    local objs=()
    [ -f "$ruta_tomo/_renombrar_folios.sh" ] && objs+=("archivo|_renombrar_folios.sh")
    [ -f "$ruta_tomo/renombrar_folios.sh" ] && objs+=("archivo|renombrar_folios.sh")
    [ -f "$ruta_tomo/_renombrar_folios.py" ] && objs+=("archivo|_renombrar_folios.py")
    [ -f "$ruta_tomo/renombrar_folios.py" ] && objs+=("archivo|renombrar_folios.py")
    [ -d "$ruta_tomo/test" ] && objs+=("carpeta|test/")
    [ -d "$ruta_tomo/_duplicados" ] && objs+=("carpeta|_duplicados/")
    
    shopt -s nullglob nocasematch
    for f in "$ruta_tomo"/*; do
        b="$(basename "$f")"
        if [[ "$b" == _temp_* ]] && [ -f "$f" ]; then
            objs+=("archivo|$b")
        elif [[ "$b" =~ \ -\ faltantes\.txt$ ]] && [ -f "$f" ]; then
            objs+=("archivo|$b")
        elif [ "$b" = "faltantes.txt" ] || [ "$b" = "configuracion.txt" ] || [ "$b" = "folios faltantes.txt" ]; then
            objs+=("archivo|$b")
        fi
    done
    shopt -u nullglob nocasematch
    echo "${objs[*]}"
}

plan_tomos=()
total_elementos=0

for nombre in "${tomos[@]}"; do
    ruta="$RAIZ/$nombre"
    res=$(recolectar_objetivos "$ruta")
    if [ -n "$res" ]; then
        plan_tomos+=("$nombre|$res")
        read -ra arr <<< "$res"
        total_elementos=$((total_elementos + ${#arr[@]}))
    fi
done

if [ $total_elementos -eq 0 ]; then
    echo "✅ No hay nada que limpiar: los tomos ya están finalizados."
    exit 0
fi

echo "Elementos a eliminar: $total_elementos"
echo ""

for entry in "${plan_tomos[@]}"; do
    t_name="${entry%%|*}"
    t_objs="${entry#*|}"
    echo "📚 $t_name"
    read -ra arr <<< "$t_objs"
    for item in "${arr[@]}"; do
        tipo="${item%%|*}"
        etiq="${item#*|}"
        echo "    · [$tipo] $etiq"
    done
done

echo ""
confirm=0
for arg in "$@"; do
    if [ "$arg" = "--yes" ] || [ "$arg" = "-y" ]; then
        confirm=1
    fi
done

if [ $confirm -eq 0 ]; then
    read -r -p "¿Confirmas la eliminación? Esta acción NO se puede deshacer [S/N]: " respuesta
    if [[ ! "$respuesta" =~ ^[Ss]$ ]]; then
        echo "❌ Operación cancelada. No se borró nada."
        exit 0
    fi
fi

echo ""
errores=0
for entry in "${plan_tomos[@]}"; do
    t_name="${entry%%|*}"
    t_objs="${entry#*|}"
    read -ra arr <<< "$t_objs"
    for item in "${arr[@]}"; do
        etiq="${item#*|}"
        target="$RAIZ/$t_name/${etiq%/}"
        if [ -d "$target" ]; then
            if rm -rf "$target"; then
                echo " 🗑️ $t_name: '$etiq' eliminado."
            else
                echo " ⚠️ $t_name: no se pudo eliminar '$etiq'"
                errores=$((errores + 1))
            fi
        elif [ -f "$target" ]; then
            if rm -f "$target"; then
                echo " 🗑️ $t_name: '$etiq' eliminado."
            else
                echo " ⚠️ $t_name: no se pudo eliminar '$etiq'"
                errores=$((errores + 1))
            fi
        fi
    done
done

echo ""
if [ $errores -gt 0 ]; then
    echo "⚠️ Limpieza terminada con $errores error(es)."
    exit 1
fi
echo "🎉 ¡LIMPIEZA COMPLETADA!"
echo "📦 Los tomos conservan solo: imágenes 'Folio X.jpg', '$REPORTE_OFICIAL', '$CONFIG_OFICIAL' y carpeta 'anexos/'."

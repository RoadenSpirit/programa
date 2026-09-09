# PROGRAMA PROCESADOR DE TOMOS (VERSIÓN BASH)

Este directorio contiene la versión en **Bash** del sistema procesador de tomos, diseñada para ejecutarse directamente en entornos Linux, macOS o Windows (vía Git Bash / WSL) sin depender de interpretadores externos.

---

## 🛠️ ARCHIVOS INCLUIDOS

1. **`_preparar_tomos.sh`** (Script Desplegador):
   - Se ejecuta desde la raíz del proyecto.
   - Detecta automáticamente las carpetas de tomos (`TOMO 164`, `tomo 165`, etc.).
   - Copia `_renombrar_folios.sh` dentro de cada tomo con permisos de ejecución.
   - Crea en cada tomo su archivo `_configuracion.txt` de BD minimalista.
   - Crea la carpeta `anexos/` en cada tomo.

2. **`_renombrar_folios.sh`** (Procesador Core del Tomo):
   - Se ejecuta dentro de la carpeta del tomo.
   - Lee `_configuracion.txt` (soporta rangos como `128-135`, folios sueltos, modo `SUBFOLIOS` o `SIMPLE`).
   - Mueve réplicas idénticas a la carpeta `_duplicados/` por HASH (SHA-256 / MD5).
   - Detecta saltos en la numeración original en la primera ejecución con BD vacía y auto-escribe en la BD.
   - Renombra imágenes en parejas alternadas: `Folio 1_1.jpg`, `Folio 1_2.jpg`, `Folio 2_1.jpg`, `Folio 2_2.jpg`... (en modo `SUBFOLIOS`).
   - Genera el reporte `_folios faltantes.txt` y la carpeta de muestras `test/` (muestreando ambas imágenes por folio cada `TAMANO_MUESTRA = 10` folios por defecto).

3. **`_limpiar_tomos.sh`** (Finalizador / Limpieza de Entrega):
   - Se ejecuta desde la raíz.
   - Elimina de cada tomo el script `_renombrar_folios.sh`, la carpeta `test/` y `_duplicados/`.
   - Respeta al 100% las imágenes renombradas, la BD `_configuracion.txt`, el reporte `_folios faltantes.txt` y la carpeta `anexos/`.

---

## 🚀 MODO DE USO (PASO A PASO)

### Paso 1: Despliegue inicial
Copia los 3 scripts `.sh` a la raíz de tu proyecto donde están las carpetas de los tomos y ejecuta:
```bash
./_preparar_tomos.sh
```

### Paso 2: Editar la BD `_configuracion.txt`
Ajusta la configuración en cada tomo si necesitas declarar saltos o cambiar parámetros:
```txt
# CONFIGURACIÓN DEL TOMO
FOLIOS_FALTANTES = 15, 128-135, 200
FOLIO_INICIAL = 1
TAMANO_MUESTRA = 10
MODO_NUMERACION = SUBFOLIOS
```

### Paso 3: Ejecutar el renombrado
Entra a cada tomo y ejecuta:
```bash
./_renombrar_folios.sh
```

### Paso 4: Limpieza final de entrega
Una vez verificadas las carpetas `test/` y los informes `_folios faltantes.txt`, ejecuta desde la raíz:
```bash
./_limpiar_tomos.sh
```
EOF

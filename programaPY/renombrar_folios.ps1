# ==============================================================================
# CONFIGURACIÓN DEL SCRIPT (POWERSHELL - NATIVO DE WINDOWS SIN PYTHON)
# ==============================================================================

# Lista de números de folios que FALTAN y deben ser SALTADOS.
# Ejemplo sin folios faltantes:  $FOLIOS_A_SALTAR = @()
# Ejemplo con folios faltantes: $FOLIOS_A_SALTAR = @(128, 129)
$FOLIOS_A_SALTAR = @()

# Tamaño del intervalo para tomar muestras de control (carpeta 'test')
$TAMANO_MUESTRA = 50

# Número de folio inicial
$FOLIO_INICIAL = 1

# Nombres de salida
$NOMBRE_REPORTE = "faltantes.txt"
$NOMBRE_CARPETA_TEST = "test"

# Carpeta actual del script
$CARPETA = $PSScriptRoot
if (-not $CARPETA) { $CARPETA = Get-Location }
Set-Location -Path $CARPETA

# ==============================================================================
# PROCESO PRINCIPAL
# ==============================================================================

Write-Host "================================================================="
Write-Host "     PROCESADOR INTEGRAL DE TOMOS Y FOLIOS (POWERSHELL NATIVO)   "
Write-Host "================================================================="
Write-Host "Carpeta: $CARPETA"
Write-Host "Folios a omitir: $(if ($FOLIOS_A_SALTAR.Count -gt 0) { $FOLIOS_A_SALTAR -join ', ' } else { 'Ninguno' })"
Write-Host "Tamaño de muestra: Cada $TAMANO_MUESTRA folios"

$files = Get-ChildItem -Path $CARPETA -File | Where-Object { 
    $_.Extension -match '^\.(jpg|jpeg|png)$' -and $_.Name -notlike '_temp_*' 
}

if ($files.Count -eq 0) {
    Write-Host "⚠️ No se encontraron imágenes en la carpeta: $CARPETA" -ForegroundColor Yellow
    exit
}

Write-Host "Total imágenes iniciales: $($files.Count)`n"

# Ordenar por número interno
$sortedFiles = $files | Sort-Object { 
    if ($_.BaseName -match '\d+') { [int]($Matches[0]) } else { $_.Name } 
}

# --------------------------------------------------------------------------
# 1. ELIMINAR DUPLICADOS
# --------------------------------------------------------------------------
Write-Host "--- 1. ELIMINANDO IMÁGENES DUPLICADAS ---"
$hashes = @{}
$unicos = @()
$duplicados = @()

foreach ($file in $sortedFiles) {
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
    if ($hashes.ContainsKey($hash)) {
        $origName = $hashes[$hash]
        $duplicados += [PSCustomObject]@{ Duplicado = $file.Name; Original = $origName }
        Remove-Item -Path $file.FullName -Force
        Write-Host " 🗑️ Duplicado eliminado: '$($file.Name)' (Idéntica a '$origName')" -ForegroundColor Yellow
    } else {
        $hashes[$hash] = $file.Name
        $unicos += $file
    }
}

if ($duplicados.Count -eq 0) {
    Write-Host "✅ No se encontraron imágenes duplicadas." -ForegroundColor Green
}
Write-Host "Total imágenes únicas a organizar: $($unicos.Count)`n"

# --------------------------------------------------------------------------
# 2. RENOMBRADO SECUENCIAL
# --------------------------------------------------------------------------
Write-Host "--- 2. RENOMBRANDO IMÁGENES ---"
$plan = @()
$folioActual = $FOLIO_INICIAL

foreach ($file in $unicos) {
    while ($FOLIOS_A_SALTAR -contains $folioActual) {
        Write-Host " ⏩ Salto aplicado: Folio $folioActual omitido por estar en la lista de faltantes." -ForegroundColor Cyan
        $folioActual++
    }
    $nuevoNombre = "Folio $folioActual.jpg"
    $plan += [PSCustomObject]@{ Original = $file.FullName; Nuevo = Join-Path $CARPETA $nuevoNombre; NombreNuevo = $nuevoNombre; NombreOrig = $file.Name }
    $folioActual++
}

$ultimoFolio = $folioActual - 1

# Renombrado en 2 fases con nombres temporales
$temporales = @()
for ($i = 0; $i -lt $plan.Count; $i++) {
    $item = $plan[$i]
    if ($item.NombreOrig -ne $item.NombreNuevo) {
        $tempPath = Join-Path $CARPETA "_temp_rename_${i}_$($item.NombreOrig)"
        Rename-Item -Path $item.Original -NewName (Split-Path $tempPath -Leaf)
        $temporales += [PSCustomObject]@{ Temp = $tempPath; Final = $item.Nuevo }
    } else {
        $temporales += [PSCustomObject]@{ Temp = $item.Original; Final = $item.Nuevo }
    }
}

foreach ($t in $temporales) {
    if ($t.Temp -ne $t.Final -and (Test-Path $t.Temp)) {
        Rename-Item -Path $t.Temp -NewName (Split-Path $t.Final -Leaf)
    }
}
Write-Host "✅ Renombrado completado." -ForegroundColor Green

# --------------------------------------------------------------------------
# 3. REPORTE FALTANTES.TXT
# --------------------------------------------------------------------------
$reportePath = Join-Path $CARPETA $NOMBRE_REPORTE
if (Test-Path $reportePath) { Remove-Item $reportePath -Force }

$lines = @(
    "=========================================================",
    "            REPORTE DE CONTROL DE FOLIOS                 ",
    "=========================================================",
    "Total imágenes útiles  : $($unicos.Count)",
    "Rango asignado         : Folio $FOLIO_INICIAL al Folio $ultimoFolio",
    "",
    "---------------------------------------------------------",
    "FOLIOS FALTANTES / OMITIDOS:",
    "---------------------------------------------------------"
)

if ($FOLIOS_A_SALTAR.Count -gt 0) {
    $lines += "Total de folios omitidos : $($FOLIOS_A_SALTAR.Count)"
    $lines += "Lista de folios faltantes : $(($FOLIOS_A_SALTAR | ForEach-Object { "Folio $_" }) -join ', ')"
    $lines += ""
} else {
    $lines += "No se omitió ningún folio (Secuencia 100% continua)."
    $lines += ""
}

if ($duplicados.Count -gt 0) {
    $lines += "---------------------------------------------------------"
    $lines += "IMÁGENES DUPLICADAS ELIMINADAS:"
    $lines += "---------------------------------------------------------"
    $lines += "Total duplicados eliminados : $($duplicados.Count)"
    foreach ($d in $duplicados) {
        $lines += " - Archivo: '$($d.Duplicado)' (Idéntica a '$($d.Original)')"
    }
}

$lines | Out-File -FilePath $reportePath -Encoding utf8
Write-Host "📄 Reporte '$NOMBRE_REPORTE' generado." -ForegroundColor Green

# --------------------------------------------------------------------------
# 4. CARPETA TEST
# --------------------------------------------------------------------------
Write-Host "--- 3. CREANDO MUESTRAS DE CONTROL ---"
$testPath = Join-Path $CARPETA $NOMBRE_CARPETA_TEST
if (Test-Path $testPath) { Remove-Item $testPath -Recurse -Force }
New-Item -ItemType Directory -Path $testPath -Force | Out-Null

$intervalo = if ($TAMANO_MUESTRA -gt 0) { $TAMANO_MUESTRA } else { 50 }
$muestrasTomadas = 0

for ($i = 0; $i -lt $plan.Count; $i++) {
    $idx = $i + 1
    $nombre = $plan[$i].NombreNuevo
    if ($idx % $intervalo -eq 0 -or $idx -eq $plan.Count) {
        $src = Join-Path $CARPETA $nombre
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination (Join-Path $testPath $nombre)
            $muestrasTomadas++
        }
    }
}

Write-Host "📂 Carpeta '$NOMBRE_CARPETA_TEST/' creada con éxito ($muestrasTomadas imágenes de muestra)." -ForegroundColor Green
Write-Host "`n🎉 ¡PROCESO FINALIZADO EXITOSAMENTE!" -ForegroundColor Green

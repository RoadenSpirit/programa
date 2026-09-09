#!/usr/bin/env python3
import os
import re
import sys
import shutil
import hashlib

_RE_FOLIO = re.compile(r'Folio\s+(\d+)', re.IGNORECASE)

def get_base_dir():
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))

CARPETA = get_base_dir()
NOMBRE_TOMO = os.path.basename(CARPETA)

EXTENSIONES_PERMITIDAS = ('.jpg', '.jpeg', '.png')
NOMBRE_CONFIG = "_configuracion.txt"
NOMBRE_REPORTE = "_folios faltantes.txt"
NOMBRE_CARPETA_TEST = "test"
NOMBRE_CARPETA_DUP = "_duplicados"

MODO_SIMPLE = 'SIMPLE'
MODO_SUBFOLIOS = 'SUBFOLIOS'

FOLIO_INICIAL_DEFECTO = 1
TAMANO_MUESTRA_DEFECTO = 10
UMBRAL_ARCHIVO_SOSPECHOSO = 2048


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


def ruta_config():
    exacta = os.path.join(CARPETA, NOMBRE_CONFIG)
    if os.path.isfile(exacta):
        return exacta
    for entrada in os.listdir(CARPETA):
        ruta = os.path.join(CARPETA, entrada)
        if (entrada.lower() == "configuracion.txt" or entrada.lower().endswith(" - faltantes.txt")) and os.path.isfile(ruta):
            return ruta
    return None


def parsear_folios(valor):
    faltantes = set()
    invalidos = []
    for token in re.split(r'[,\s;]+', valor.strip()):
        if not token:
            continue
        rango = re.fullmatch(r'(\d+)\s*[-–]\s*(\d+)', token)
        if rango:
            a, b = int(rango.group(1)), int(rango.group(2))
            if a > b:
                a, b = b, a
            faltantes.update(range(a, b + 1))
            continue
        if re.fullmatch(r'\d+', token):
            if int(token) != 0:
                faltantes.add(int(token))
            continue
        invalidos.append(token)
    return faltantes, invalidos


def normalizar_modo(valor):
    v = re.sub(r'[\s\-_]', '', valor.strip().upper())
    if v in ('SUBFOLIOS', 'SUBFOLIO'):
        return MODO_SUBFOLIOS
    if v in ('SIMPLE', 'NORMAL', 'CLASICO', ''):
        return MODO_SIMPLE
    return None


def leer_config():
    cfg = {
        'folios': set(),
        'inicial': FOLIO_INICIAL_DEFECTO,
        'muestra': TAMANO_MUESTRA_DEFECTO,
        'modo': MODO_SUBFOLIOS,
    }
    avisos = []
    ruta = ruta_config()
    with open(ruta, 'r', encoding='utf-8-sig') as f:
        for linea in f:
            limpia = linea.strip()
            if not limpia or limpia.startswith('#') or '=' not in limpia:
                continue
            clave, _, valor = limpia.partition('=')
            clave = clave.strip().upper()
            valor = valor.strip()
            if clave in ('FOLIOS_FALTANTES', 'FOLIOS_A_SALTAR'):
                folios, invalidos = parsear_folios(valor)
                cfg['folios'] |= folios
                avisos.extend(f"Token no válido en {clave}: '{t}'" for t in invalidos)
            elif clave == 'FOLIO_INICIAL':
                try:
                    cfg['inicial'] = max(1, int(valor))
                except ValueError:
                    avisos.append(f"FOLIO_INICIAL no válido: '{valor}' (se usa {FOLIO_INICIAL_DEFECTO})")
            elif clave == 'TAMANO_MUESTRA':
                try:
                    cfg['muestra'] = max(1, int(valor))
                except ValueError:
                    avisos.append(f"TAMANO_MUESTRA no válido: '{valor}' (se usa {TAMANO_MUESTRA_DEFECTO})")
            elif clave == 'MODO_NUMERACION':
                modo = normalizar_modo(valor)
                if modo is None:
                    avisos.append(f"MODO_NUMERACION no válido: '{valor}' (se usa {MODO_SUBFOLIOS})")
                else:
                    cfg['modo'] = modo
    return cfg, avisos


def extraer_tokens(nombre):
    sin_ext = os.path.splitext(nombre)[0]
    return tuple(int(t) for t in re.findall(r'\d+', sin_ext))


def numero_principal(nombre):
    tokens = extraer_tokens(nombre)
    return tokens[0] if tokens else None


def clave_orden(nombre):
    tokens = extraer_tokens(nombre)
    if not tokens:
        return (1, (), nombre.lower())
    return (0, tokens, '')


def calcular_hash(ruta_archivo):
    hasher = hashlib.sha256()
    with open(ruta_archivo, 'rb') as f:
        while chunk := f.read(1024 * 1024):
            hasher.update(chunk)
    return hasher.hexdigest()


def formatear_como_rangos(numeros):
    ordenados = sorted(numeros)
    partes = []
    i = 0
    while i < len(ordenados):
        j = i
        while j + 1 < len(ordenados) and ordenados[j + 1] == ordenados[j] + 1:
            j += 1
        if j > i:
            partes.append(f"{ordenados[i]}-{ordenados[j]}")
        else:
            partes.append(str(ordenados[i]))
        i = j + 1
    return ", ".join(partes)


def huecos_de_secuencia(numeros):
    ordenados = sorted(set(numeros))
    huecos = set()
    for a, b in zip(ordenados, ordenados[1:]):
        if b > a + 1:
            huecos.update(range(a + 1, b))
    return huecos


def actualizar_bd_faltantes(ruta_cfg, faltantes):
    with open(ruta_cfg, 'r', encoding='utf-8-sig') as f:
        lineas = f.readlines()
    nueva_linea = f"FOLIOS_FALTANTES = {formatear_como_rangos(faltantes)}\n" if faltantes else "FOLIOS_FALTANTES =\n"

    reemplazada = False
    for i, linea in enumerate(lineas):
        if re.match(r'\s*(FOLIOS_FALTANTES|FOLIOS_A_SALTAR)\s*=', linea, re.IGNORECASE):
            lineas[i] = nueva_linea
            reemplazada = True
            break
    if not reemplazada:
        if lineas and not lineas[-1].endswith('\n'):
            lineas.append('\n')
        lineas.append(nueva_linea)
    with open(ruta_cfg, 'w', encoding='utf-8') as f:
        f.writelines(lineas)


def detectar_anomalias(entradas):
    numerados = []
    sospechosos = []
    for e in entradas:
        try:
            size = e.stat().st_size
        except OSError:
            size = -1
        if size < UMBRAL_ARCHIVO_SOSPECHOSO:
            sospechosos.append(e.name)
        num = numero_principal(e.name)
        if num is not None:
            numerados.append((num, e.name))

    numerados.sort()
    saltos = []
    prev_n = None
    prev_a = None
    for n, a in numerados:
        if prev_n is not None and n > prev_n + 1:
            saltos.append((prev_a, a, n - prev_n - 1))
        if prev_n is None or n != prev_n:
            prev_n = n
            prev_a = a

    sin_numero = [e.name for e in entradas if numero_principal(e.name) is None]
    return saltos, sospechosos, sin_numero


def mover_a_duplicados(nombre):
    carpeta_dup = os.path.join(CARPETA, NOMBRE_CARPETA_DUP)
    destino = os.path.join(carpeta_dup, nombre)
    if os.path.exists(destino):
        base, ext = os.path.splitext(nombre)
        k = 2
        while os.path.exists(destino):
            destino = os.path.join(carpeta_dup, f"{base}_repetido_{k}{ext}")
            k += 1
    shutil.move(os.path.join(CARPETA, nombre), destino)
    return os.path.basename(destino)


def renombrar_archivos_seguro(plan_renombrado):
    temporales = []
    for i, (antigua, nueva, orig, nuevo) in enumerate(plan_renombrado):
        if orig != nuevo:
            temp_path = os.path.join(CARPETA, f"_temp_rename_{i}_{orig}")
            os.rename(antigua, temp_path)
            temporales.append((temp_path, nueva))
        else:
            temporales.append((antigua, nueva))

    for temp_path, final_path in temporales:
        if temp_path != final_path and os.path.exists(temp_path):
            os.rename(temp_path, final_path)


def guardar_reporte(ruta_txt, contenido):
    if os.path.exists(ruta_txt):
        try:
            os.remove(ruta_txt)
        except Exception:
            pass
    with open(ruta_txt, "w", encoding="utf-8") as f:
        f.write(contenido)


def generar_carpeta_test(plan_final, intervalo):
    carpeta_test = os.path.join(CARPETA, NOMBRE_CARPETA_TEST)

    groups = {}
    order_bases = []
    for _, _, _, nombre in plan_final:
        match = _RE_FOLIO.match(nombre)
        base = int(match.group(1)) if match else nombre
        if base not in groups:
            groups[base] = []
            order_bases.append(base)
        groups[base].append(nombre)

    muestras = []
    for idx, base in enumerate(order_bases, start=1):
        if idx % intervalo == 0 or idx == len(order_bases):
            muestras.extend(groups[base])
    muestras = list(dict.fromkeys(muestras))

    if os.path.exists(carpeta_test):
        shutil.rmtree(carpeta_test, ignore_errors=True)
    os.makedirs(carpeta_test, exist_ok=True)

    tomadas = 0
    for m in muestras:
        src = os.path.join(CARPETA, m)
        dst = os.path.join(carpeta_test, m)
        if os.path.exists(src):
            shutil.copy2(src, dst)
            tomadas += 1
    return tomadas, len(plan_final)


def construir_plan(archivos_unicos, saltar_set, inicial, modo):
    plan_final = []
    asignados = []
    info = {'subfolios': 0}

    if modo == MODO_SUBFOLIOS:
        modo_efectivo = 'subfolios'
    elif any(numero_principal(a) is None for a in archivos_unicos):
        modo_efectivo = 'secuencial'
    else:
        modo_efectivo = 'directo'

    if modo_efectivo == 'secuencial':
        folio_actual = inicial
        for archivo in archivos_unicos:
            while folio_actual in saltar_set:
                folio_actual += 1
            nombre_final = f"Folio {folio_actual}.jpg"
            plan_final.append((
                os.path.join(CARPETA, archivo),
                os.path.join(CARPETA, nombre_final),
                archivo,
                nombre_final,
            ))
            asignados.append(folio_actual)
            folio_actual += 1

    elif modo_efectivo == 'directo':
        offset = inicial - extraer_base_minima(archivos_unicos)
        for archivo in archivos_unicos:
            folio = numero_principal(archivo) + offset
            nombre_final = f"Folio {folio}.jpg"
            plan_final.append((
                os.path.join(CARPETA, archivo),
                os.path.join(CARPETA, nombre_final),
                archivo,
                nombre_final,
            ))
            asignados.append(folio)

    else:
        # Modo SUBFOLIOS: renombra secuencialmente en parejas 1_1, 1_2, 2_1, 2_2... respetando saltar_set
        folio_base = inicial
        sub_idx = 1
        for archivo in archivos_unicos:
            while folio_base in saltar_set:
                folio_base += 1
                sub_idx = 1
            nombre_final = f"Folio {folio_base}_{sub_idx}.jpg"
            info['subfolios'] += 1
            asignados.append(folio_base)
            if sub_idx == 1:
                sub_idx = 2
            else:
                sub_idx = 1
                folio_base += 1
            plan_final.append((
                os.path.join(CARPETA, archivo),
                os.path.join(CARPETA, nombre_final),
                archivo,
                nombre_final,
            ))

    return plan_final, asignados, modo_efectivo, info


def extraer_base_minima(archivos_unicos):
    return min(numero_principal(a) for a in archivos_unicos)


def procesar_tomo():
    print("=================================================================")
    print("              PROCESADOR INTEGRAL DE TOMOS Y FOLIOS               ")
    print("=================================================================")

    ruta_cfg = ruta_config()
    if ruta_cfg is None:
        nueva_ruta = os.path.join(CARPETA, NOMBRE_CONFIG)
        with open(nueva_ruta, "w", encoding="utf-8") as f:
            f.write(plantilla_config())
        print(f"⚠️ Se ha creado la plantilla '{NOMBRE_CONFIG}'.")
        print("✏️  Edítalo si necesitas cambiar la configuración y vuelve a ejecutar.")
        ruta_cfg = nueva_ruta

    print(f"Tomo      : {NOMBRE_TOMO}")
    print(f"Config BD : {os.path.basename(ruta_cfg)}")

    cfg, avisos_config = leer_config()
    declarados = cfg['folios']
    for aviso in avisos_config:
        print(f" ⚠️ {aviso}")

    archivos = [
        f for f in os.listdir(CARPETA)
        if os.path.isfile(os.path.join(CARPETA, f))
        and f.lower().endswith(EXTENSIONES_PERMITIDAS)
        and not f.startswith('_temp_')
        and not f.startswith('.')
    ]
    entradas = []
    with os.scandir(CARPETA) as it:
        for e in it:
            if e.is_file() and e.name in archivos:
                entradas.append(e)

    if not archivos:
        print(f"⚠️ No se encontraron imágenes en la carpeta: {CARPETA}")
        sys.exit(1)

    print(f"Modo de numeración       : {cfg['modo']}")
    print(f"Folios omitidos declarados ({len(declarados)}): "
          f"{formatear_como_rangos(declarados) if declarados else 'Ninguno'}")
    print(f"Muestras de control: cada {cfg['muestra']} folios")
    print(f"Total imágenes iniciales: {len(archivos)}\n")

    archivos.sort(key=clave_orden)
    entradas.sort(key=lambda e: clave_orden(e.name))

    print("--- 1. ANALIZANDO ANOMALÍAS EN LOS ORIGINALES ---")
    saltos_origen, sospechosos, sin_numero = detectar_anomalias(entradas)
    if saltos_origen:
        print(" ⚠️ Saltos detectados en la secuencia original:")
        for anterior, siguiente, cuantos in saltos_origen:
            print(f"    · Entre '{anterior}' y '{siguiente}' faltan {cuantos} números.")
    else:
        print(" ✅ Secuencia original continua.")
    if sospechosos:
        print(f" ⚠️ Archivos sospechosos (<{UMBRAL_ARCHIVO_SOSPECHOSO} bytes): {', '.join(sospechosos)}")
    if sin_numero:
        print(f" ⚠️ Archivos sin número en el nombre: {', '.join(sin_numero)}")
    print()

    print("--- 2. DUPLICADOS -> CARPETA '_duplicados/' ---")
    hashes_vistos = {}
    archivos_unicos = []
    duplicados_detectados = []
    for archivo in archivos:
        h = calcular_hash(os.path.join(CARPETA, archivo))
        if h in hashes_vistos:
            duplicados_detectados.append((archivo, hashes_vistos[h]))
        else:
            hashes_vistos[h] = archivo
            archivos_unicos.append(archivo)

    if duplicados_detectados:
        os.makedirs(os.path.join(CARPETA, NOMBRE_CARPETA_DUP), exist_ok=True)
        for dup, origen in duplicados_detectados:
            final_dup = mover_a_duplicados(dup)
            print(f" 📦 Movido a '{NOMBRE_CARPETA_DUP}/': '{dup}' (Idéntica a '{origen}')")
    else:
        print("✅ No se encontraron imágenes duplicadas.")

    print(f"Total imágenes únicas a organizar: {len(archivos_unicos)}\n")

    print("--- 3. RENOMBRADO PROGRESIVO ---")
    bases_principales = [n for n in (numero_principal(a) for a in archivos_unicos) if n is not None]
    
    if cfg['modo'] == MODO_SUBFOLIOS and len(bases_principales) > 1:
        folios_implicitos = [(n + 1) // 2 for n in bases_principales]
        faltantes_detectados = huecos_de_secuencia(folios_implicitos)
    else:
        faltantes_detectados = huecos_de_secuencia(bases_principales)

    # AUTO-DETECCIÓN SOLO EN LA PRIMERA EJECUCIÓN CON BD VACÍA
    es_primera_ejecucion = not any(a.startswith('Folio ') for a in archivos_unicos)
    esta_bd_vacia = len(declarados) == 0

    if es_primera_ejecucion and esta_bd_vacia and faltantes_detectados:
        actualizar_bd_faltantes(ruta_cfg, faltantes_detectados)
        faltantes_totales = faltantes_detectados
        print(f" 📝 BD inicializada automáticamente con los saltos del escáner: "
              f"{formatear_como_rangos(faltantes_detectados)}")
    else:
        faltantes_totales = declarados

    plan_final, asignados, modo_efectivo, info = construir_plan(
        archivos_unicos, faltantes_totales, cfg['inicial'], cfg['modo']
    )
    asignados_set = set(asignados)
    conflictos = sorted(faltantes_totales & asignados_set)
    reservados = sorted(faltantes_totales - asignados_set)
    ultimo_folio_generado = max(asignados_set) if asignados_set else cfg['inicial'] - 1

    renombrar_archivos_seguro(plan_final)

    if modo_efectivo == 'directo':
        print(" ✅ Modo directo: cada imagen conservó su número original como folio.")
    elif modo_efectivo == 'subfolios':
        print(f" ✅ Modo SUBFOLIOS: jerarquía conservada "
              f"({info['subfolios']} sub-folios tipo 'Folio X_1.jpg', 'Folio X_2.jpg').")
    else:
        print(" ✅ Modo secuencial (había archivos sin número en el nombre).")
    print(f" ✅ Renombrado completado: Folio {cfg['inicial']} al Folio {ultimo_folio_generado} "
          f"({len(reservados)} folios reservados).\n")

    print(f"--- 4. GENERANDO REPORTE '{NOMBRE_REPORTE}' ---")
    lineas = [
        "=========================================================",
        "            REPORTE DE CONTROL DE FOLIOS                 ",
        "=========================================================",
        f"Tomo                  : {NOMBRE_TOMO}",
        f"Modo de numeración    : {cfg['modo']}",
        f"Total imágenes útiles : {len(archivos_unicos)}",
        f"Rango asignado        : Folio {cfg['inicial']} al Folio {ultimo_folio_generado}",
    ]
    if info['subfolios']:
        lineas.append(f"Sub-folios (X_1, X_2) : {info['subfolios']}")
    lineas.extend([
        "",
        "---------------------------------------------------------",
        "FOLIOS FALTANTES / OMITIDOS:",
        "---------------------------------------------------------",
    ])
    if faltantes_totales:
        lineas.append(f"Total omitidos : {len(faltantes_totales)} "
                      f"(Folios: {formatear_como_rangos(faltantes_totales)})")
        if es_primera_ejecucion and esta_bd_vacia and faltantes_detectados:
            lineas.append(f"Auto-detectados por saltos del escáner: {formatear_como_rangos(faltantes_detectados)}")
        lineas.append("")
    else:
        lineas.append("No se omitió ningún folio (Secuencia 100% continua).\n")

    if duplicados_detectados:
        lineas.extend([
            "---------------------------------------------------------",
            f"IMÁGENES DUPLICADAS MOVIDAS A '{NOMBRE_CARPETA_DUP}/':",
            "---------------------------------------------------------",
            f"Total duplicados movidos : {len(duplicados_detectados)}"
        ])
        for dup, origen in duplicados_detectados:
            lineas.append(f" - Archivo: '{dup}' (Idéntica a '{origen}')")
        lineas.append("")

    if saltos_origen or sospechosos or sin_numero:
        lineas.extend([
            "---------------------------------------------------------",
            "ANOMALÍAS DETECTADAS EN ARCHIVOS ORIGINALES:",
            "---------------------------------------------------------",
        ])
        for anterior, siguiente, cuantos in saltos_origen:
            lineas.append(f" - Salto en secuencia original: entre '{anterior}' y "
                          f"'{siguiente}' faltan {cuantos} números.")
        for s in sospechosos:
            lineas.append(f" - Archivo sospechoso (<{UMBRAL_ARCHIVO_SOSPECHOSO} bytes): '{s}'")
        for s in sin_numero:
            lineas.append(f" - Archivo sin número en el nombre: '{s}'")
        lineas.append("")

    if conflictos:
        lineas.extend([
            "---------------------------------------------------------",
            "AVISO:",
            "---------------------------------------------------------",
            "Folios declarados pero con imagen existente:",
            f"  {', '.join(str(n) for n in conflictos)}",
        ])

    guardar_reporte(os.path.join(CARPETA, NOMBRE_REPORTE), "\n".join(lineas))
    print(f"📄 Reporte '{NOMBRE_REPORTE}' generado.\n")

    print("--- 5. CREANDO MUESTRAS DE CONTROL 'test/' ---")
    tomadas, total = generar_carpeta_test(plan_final, cfg['muestra'])
    print(f"📂 Carpeta '{NOMBRE_CARPETA_TEST}/' creada ({tomadas} de {total} folios muestreados).")

    print("\n🎉 ¡PROCESO FINALIZADO EXITOSAMENTE!")


if __name__ == "__main__":
    procesar_tomo()

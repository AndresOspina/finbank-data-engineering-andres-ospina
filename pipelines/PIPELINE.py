import os
import sys
import subprocess
import uuid
import time
from datetime import datetime

import pandas as pd
import pyodbc


BASE = os.path.dirname(os.path.abspath(__file__))
PROYECTO = os.path.dirname(BASE)
SQL_DIR = os.path.join(BASE, "SQL")
DATOS_DIR = os.path.join(PROYECTO, "data-generation")
PARQUET_DIR = os.path.join(BASE, "output", "bronze_parquet")

SERVER = r"localhost\SQLEXPRESS"
DATABASE = "FINBANK"

TABLAS_BRONZE = [
    "TB_CLIENTES_CORE",
    "TB_PRODUCTOS_CAT",
    "TB_SUCURSALES_RED",
    "TB_OBLIGACIONES",
    "TB_MOV_FINANCIEROS",
    "TB_COMISIONES_LOG",
    "TB_INCENTIVOS"
]


def titulo(texto):
    print(f"\n--- {texto} ---")


def conectar():
    return pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};"
        f"SERVER={SERVER};DATABASE={DATABASE};"
        "Trusted_Connection=yes;TrustServerCertificate=yes;"
    )


def ejecutar_python(archivo):
    r = subprocess.run(
        [sys.executable, os.path.join(DATOS_DIR, archivo)],
        cwd=BASE,
        capture_output=True,
        text=True
    )
    if r.returncode != 0:
        raise RuntimeError(r.stderr or f"Error ejecutando {archivo}")


def dividir_sql(texto):
    bloques = []
    actual = []

    for linea in texto.splitlines():
        if linea.strip().upper() == "GO":
            if actual:
                bloques.append("\n".join(actual))
                actual = []
        else:
            actual.append(linea)

    if actual:
        bloques.append("\n".join(actual))

    return bloques


def ejecutar_sql(cursor, archivo):
    with open(os.path.join(SQL_DIR, archivo), encoding="utf-8-sig") as f:
        bloques = dividir_sql(f.read())

    for n, sql in enumerate(bloques, 1):
        if not sql.strip():
            continue

        try:
            cursor.execute(sql)
            while True:
                if cursor.description:
                    cursor.fetchall()
                if not cursor.nextset():
                    break
        except Exception as e:
            raise RuntimeError(f"{archivo} - batch {n}: {e}") from e


def consultar(con, sql, params=()):
    cur = con.cursor()
    cur.execute(sql, *params)
    columnas = [x[0] for x in cur.description]
    filas = cur.fetchall()
    cur.close()
    return columnas, filas


def dataframe(con, sql, params=()):
    columnas, filas = consultar(con, sql, params)
    return pd.DataFrame([tuple(f) for f in filas], columns=columnas)


def crear_logs(con):
    cur = con.cursor()

    cur.execute("""
    IF OBJECT_ID('dbo.PIPELINE_ERROR_LOG','U') IS NULL
    CREATE TABLE dbo.PIPELINE_ERROR_LOG(
        id_error BIGINT IDENTITY PRIMARY KEY,
        id_ejecucion UNIQUEIDENTIFIER NOT NULL,
        etapa VARCHAR(50) NOT NULL,
        proceso VARCHAR(150) NOT NULL,
        tipo_error VARCHAR(100) NOT NULL,
        mensaje_error NVARCHAR(2000) NOT NULL,
        fecha_error DATETIME2(3) DEFAULT SYSDATETIME(),
        estado VARCHAR(20) DEFAULT 'REGISTRADO'
    );

    IF OBJECT_ID('dbo.BRONZE_INGESTION_LOG','U') IS NULL
    CREATE TABLE dbo.BRONZE_INGESTION_LOG(
        id_log BIGINT IDENTITY PRIMARY KEY,
        id_ejecucion UNIQUEIDENTIFIER NOT NULL,
        tabla VARCHAR(100) NOT NULL,
        fecha_inicio DATETIME2(3) NOT NULL,
        fecha_fin DATETIME2(3) NOT NULL,
        duracion_segundos DECIMAL(18,3) NOT NULL,
        registros_procesados INT NOT NULL,
        tamano_archivo_bytes BIGINT NOT NULL,
        ruta_archivo NVARCHAR(2000),
        watermark_desde DATETIME2(7),
        watermark_hasta DATETIME2(7),
        estado VARCHAR(20) NOT NULL,
        mensaje_error NVARCHAR(2000)
    );
    """)

    con.commit()
    cur.close()


def registrar_error(con, etapa, error):
    cur = con.cursor()

    cur.execute("""
        INSERT INTO dbo.PIPELINE_ERROR_LOG
        (id_ejecucion, etapa, proceso, tipo_error, mensaje_error, estado)
        VALUES (?, ?, ?, ?, ?, 'ERROR')
    """,
        str(uuid.uuid4()),
        etapa,
        "Pipeline principal",
        type(error).__name__,
        str(error)[:2000]
    )

    con.commit()
    cur.close()


def obtener_watermark(con, tabla):
    _, filas = consultar(con, """
        SELECT TOP 1 watermark_hasta
        FROM dbo.BRONZE_INGESTION_LOG
        WHERE tabla = ?
          AND estado IN ('OK','SIN_CAMBIOS')
          AND watermark_hasta IS NOT NULL
        ORDER BY id_log DESC
    """, (tabla,))

    return filas[0][0] if filas else None


def guardar_log_bronze(con, valores):
    cur = con.cursor()

    cur.execute("""
        INSERT INTO dbo.BRONZE_INGESTION_LOG
        (id_ejecucion, tabla, fecha_inicio, fecha_fin,
         duracion_segundos, registros_procesados,
         tamano_archivo_bytes, ruta_archivo,
         watermark_desde, watermark_hasta, estado, mensaje_error)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, *valores)

    con.commit()
    cur.close()


def exportar_parquet(con):
    archivos = 0
    registros = 0
    errores = 0

    for tabla in TABLAS_BRONZE:
        fecha_inicio = datetime.now()
        inicio = time.perf_counter()
        watermark = obtener_watermark(con, tabla)
        id_ejecucion = uuid.uuid4()
        rutas = []

        try:
            if watermark is None:
                df = dataframe(
                    con,
                    f"SELECT * FROM bronze.{tabla} ORDER BY fecha_ingesta"
                )
            else:
                df = dataframe(
                    con,
                    f"""
                    SELECT *
                    FROM bronze.{tabla}
                    WHERE DATEDIFF_BIG(MICROSECOND, ?, fecha_ingesta) > 0
                    ORDER BY fecha_ingesta
                    """,
                    (watermark,)
                )

            if df.empty:
                guardar_log_bronze(con, (
                    str(id_ejecucion),
                    tabla,
                    fecha_inicio,
                    datetime.now(),
                    time.perf_counter() - inicio,
                    0,
                    0,
                    None,
                    watermark,
                    watermark,
                    "SIN_CAMBIOS",
                    None
                ))
                continue

            df["fecha_ingesta"] = pd.to_datetime(df["fecha_ingesta"])
            watermark_nuevo = df["fecha_ingesta"].max().to_pydatetime()

            for fecha, grupo in df.groupby(df["fecha_ingesta"].dt.date):
                ruta = os.path.join(
                    PARQUET_DIR,
                    tabla,
                    f"anio={fecha.year}",
                    f"mes={fecha.month:02d}",
                    f"dia={fecha.day:02d}"
                )

                os.makedirs(ruta, exist_ok=True)

                archivo = os.path.join(
                    ruta,
                    f"part-{id_ejecucion}.parquet"
                )

                grupo.to_parquet(archivo, engine="pyarrow", index=False)
                rutas.append(archivo)

            tamano = sum(os.path.getsize(ruta) for ruta in rutas)

            guardar_log_bronze(con, (
                str(id_ejecucion),
                tabla,
                fecha_inicio,
                datetime.now(),
                time.perf_counter() - inicio,
                len(df),
                tamano,
                ";".join(rutas),
                watermark,
                watermark_nuevo,
                "OK",
                None
            ))

            archivos += len(rutas)
            registros += len(df)

        except Exception as e:
            errores += 1

            guardar_log_bronze(con, (
                str(id_ejecucion),
                tabla,
                fecha_inicio,
                datetime.now(),
                time.perf_counter() - inicio,
                0,
                0,
                None,
                watermark,
                watermark,
                "ERROR",
                str(e)[:2000]
            ))

    return archivos, registros, errores


def resumen_bronze(con, parquet):
    titulo("BRONZE")
    print("Guarda los datos originales y procesa solo registros nuevos.")

    _, filas = consultar(con, """
        SELECT tabla, estado, registros_procesados, watermark_hasta
        FROM dbo.BRONZE_INGESTION_LOG
        WHERE id_log IN (
            SELECT MAX(id_log)
            FROM dbo.BRONZE_INGESTION_LOG
            GROUP BY tabla
        )
        ORDER BY tabla
    """)

    nuevos = sum(int(f[2]) for f in filas)
    auditadas = sum(1 for f in filas if f[3] is not None)

    print(
        f"Resultado: {len(filas)} tablas verificadas | "
        f"{nuevos} registros nuevos | Errores: {parquet[2]}"
    )

    if nuevos == 0 and parquet[2] == 0:
        print("Incremental: SIN_CAMBIOS - no se reprocesaron datos existentes.")
    else:
        print(
            f"Incremental: {parquet[1]} registros procesados | "
            f"{parquet[0]} archivo(s) Parquet."
        )

    print(f"Auditoria/Watermark: {auditadas}/{len(filas)} tablas OK")
    print("Parquet particionado: OK" if parquet[2] == 0 else "Parquet: ERROR")


def resumen_silver(con):
    titulo("SILVER")
    print("Limpia, valida y separa los datos incorrectos.")

    _, filas = consultar(con, """
        WITH ultimos AS (
            SELECT tabla, registros_bronze, registros_silver,
                   registros_rechazados, porcentaje_conformidad,
                   ROW_NUMBER() OVER (
                       PARTITION BY tabla
                       ORDER BY fecha_ejecucion DESC
                   ) rn
            FROM silver.reporte_calidad
        )
        SELECT tabla, registros_bronze, registros_silver,
               registros_rechazados, porcentaje_conformidad
        FROM ultimos
        WHERE rn = 1
        ORDER BY tabla
    """)

    recibidos = sum(int(f[1]) for f in filas)
    validos = sum(int(f[2]) for f in filas)
    rechazados = sum(int(f[3]) for f in filas)
    calidad = validos / recibidos * 100 if recibidos else 0

    print(
        f"Resultado: {validos} validos | {rechazados} rechazado(s) | "
        f"Calidad global: {calidad:.2f}%"
    )

    print("\nCalidad por tabla:")
    for f in filas:
        print(
            f"{f[0]}: {f[2]}/{f[1]} validos | "
            f"{f[3]} rechazados | {f[4]}%"
        )

    _, rechazados = consultar(con, """
        SELECT TOP 1 id_oblig, id_cli, tipo_error, motivo_rechazo
        FROM silver.obligaciones_rechazadas
        ORDER BY fecha_rechazo DESC
    """)

    if rechazados:
        f = rechazados[0]
        print("\nDato rechazado:")
        print(f"Obligacion: {f[0]} | Cliente: {f[1]}")
        print(f"Error: {f[2]}")
        print(f"Motivo: {f[3]}")

    _, sospechosas = consultar(con, """
        SELECT TOP 1 id_mov, id_cli, vr_mov, total_alertas
        FROM silver.movimientos
        WHERE ind_sospechoso = 1
        ORDER BY id_mov DESC
    """)

    if sospechosas:
        f = sospechosas[0]
        print("\nTransaccion sospechosa:")
        print(
            f"Movimiento: {f[0]} | Cliente: {f[1]} | "
            f"Monto: ${float(f[2]):,.0f}"
        )
        print(f"Alertas detectadas: {f[3]}")


def resumen_gold(con):
    titulo("GOLD")
    print("Genera la informacion final para analisis y negocio.")

    _, sospechosas = consultar(con, """
        SELECT TOP 1
            ft.id_mov,
            dc.id_cli,
            ft.monto_cop,
            ft.total_alertas,
            ft.ind_sospechoso
        FROM gold.fact_transacciones ft
        JOIN gold.dim_clientes dc
          ON ft.cliente_key = dc.cliente_key
        WHERE ft.ind_sospechoso = 1
        ORDER BY ft.id_mov DESC
    """)

    if sospechosas:
        f = sospechosas[0]
        print("\nTransaccion sospechosa:")
        print(
            f"Movimiento: {f[0]} | Cliente: {f[1]} | "
            f"Monto: ${float(f[2]):,.0f}"
        )
        print(f"Alertas detectadas: {f[3]} | Indicador sospechoso: {f[4]}")

    _, cartera = consultar(con, """
        SELECT
            COUNT(*),
            SUM(CASE WHEN clasificacion_regulatoria='A' THEN 1 ELSE 0 END),
            SUM(CASE WHEN clasificacion_regulatoria='B' THEN 1 ELSE 0 END),
            SUM(CASE WHEN clasificacion_regulatoria='C' THEN 1 ELSE 0 END),
            SUM(CASE WHEN clasificacion_regulatoria='D' THEN 1 ELSE 0 END),
            SUM(CASE WHEN clasificacion_regulatoria='E' THEN 1 ELSE 0 END),
            SUM(CASE WHEN provision_estimada IS NULL THEN 1 ELSE 0 END)
        FROM gold.fact_cartera
    """)

    if cartera:
        f = cartera[0]
        print("\nCartera:")
        print(
            f"Total: {f[0]} | A: {f[1]} | B: {f[2]} | "
            f"C: {f[3]} | D: {f[4]} | E: {f[5]}"
        )
        print(f"Provisiones nulas: {f[6]}")

    _, cliente360 = consultar(con, """
        SELECT COUNT(*), COUNT(DISTINCT cliente_key)
        FROM gold.vista_cliente_360
    """)

    if cliente360:
        print(
            f"\nCliente 360: {cliente360[0][0]} registros | "
            f"{cliente360[0][1]} clientes unicos"
        )

    _, relaciones = consultar(con, """
        SELECT
            SUM(CASE WHEN cliente_key IS NULL THEN 1 ELSE 0 END) +
            SUM(CASE WHEN producto_key IS NULL THEN 1 ELSE 0 END) +
            SUM(CASE WHEN canal_key IS NULL THEN 1 ELSE 0 END) +
            SUM(CASE WHEN geografia_key IS NULL THEN 1 ELSE 0 END)
        FROM gold.fact_transacciones
    """)

    faltantes = relaciones[0][0] or 0

    print(f"Relaciones faltantes: {faltantes}")
    print("Resultado Gold: OK" if faltantes == 0 else "Resultado Gold: REVISAR")


def resumen_pruebas(con):
    titulo("PRUEBAS AUTOMATIZADAS")
    print("Valida automaticamente la calidad de los datos finales.\n")

    _, filas = consultar(con, """
        SELECT nombre_prueba, capa, resultado,
               valor_observado, valor_esperado
        FROM dbo.RESULTADO_PRUEBAS_CALIDAD
        WHERE id_ejecucion = (
            SELECT TOP 1 id_ejecucion
            FROM dbo.RESULTADO_PRUEBAS_CALIDAD
            ORDER BY id_resultado DESC
        )
        ORDER BY id_resultado
    """)

    for i, f in enumerate(filas, 1):
        print(
            f"{i}. {f[0]} | {f[2]} | "
            f"Observado: {f[3]} | Esperado: {f[4]}"
        )

    aprobadas = sum(str(f[2]).upper() == "PASS" for f in filas)
    fallidas = len(filas) - aprobadas

    print(
        f"\nResultado: {len(filas)} pruebas | "
        f"{aprobadas} PASS | {fallidas} FAIL"
    )

    return fallidas


def resumen_errores(con):
    titulo("MANEJO DE ERRORES")
    print("Comprueba que los errores queden registrados.")

    _, filas = consultar(con, """
        SELECT TOP 1 proceso, tipo_error, estado
        FROM dbo.PIPELINE_ERROR_LOG
        WHERE tipo_error = 'ERROR_PRUEBA_CONTROLADO'
        ORDER BY id_error DESC
    """)

    if filas:
        f = filas[0]
        print(f"Prueba: {f[0]}")
        print(f"Tipo: {f[1]}")
        print(f"Estado: {f[2]}")
        print("Resultado: Log de errores funcionando correctamente.")
    else:
        print("Resultado: No se encontro la prueba controlada.")


def main():
    con = None
    cursor = None
    etapa = "INICIO"

    try:
        print("\nFINBANK - PIPELINE DE DATOS")

        etapa = "GENERACION"
        titulo("GENERACION DE DATOS")
        print("Genera los datos de prueba utilizados por el pipeline.")
        ejecutar_python("GENERAR_DATOS.py")
        print("Resultado: 140 registros generados | Estado: OK")

        etapa = "CARGA"
        titulo("CARGA DE DATOS")
        print("Carga los datos generados en SQL Server.")
        ejecutar_python("CARGAR_DATOS.py")
        print("Resultado: Datos cargados correctamente | Estado: OK")

        con = conectar()
        crear_logs(con)
        cursor = con.cursor()

        etapa = "BRONZE"
        ejecutar_sql(cursor, "bronze.sql")
        con.commit()
        parquet = exportar_parquet(con)
        resumen_bronze(con, parquet)

        etapa = "SILVER"
        ejecutar_sql(cursor, "silver.sql")
        con.commit()
        resumen_silver(con)

        etapa = "GOLD"
        ejecutar_sql(cursor, "gold.sql")
        con.commit()
        resumen_gold(con)

        etapa = "VALIDACIONES"
        ejecutar_sql(cursor, "validaciones.sql")
        con.commit()
        fallos = resumen_pruebas(con)
        resumen_errores(con)

        titulo("RESULTADO FINAL")

        if parquet[2] == 0 and fallos == 0:
            print("PIPELINE FINALIZADO CORRECTAMENTE")
        else:
            print(
                f"PIPELINE CON ALERTAS | "
                f"Errores Bronze: {parquet[2]} | Pruebas FAIL: {fallos}"
            )

    except Exception as e:
        if con:
            try:
                con.rollback()
                registrar_error(con, etapa, e)
            except Exception:
                pass

        print(f"\nERROR | Etapa: {etapa}")
        print(e)
        sys.exit(1)

    finally:
        if cursor:
            cursor.close()
        if con:
            con.close()


if __name__ == "__main__":
    main()
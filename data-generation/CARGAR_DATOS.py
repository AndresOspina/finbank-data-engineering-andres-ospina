from pathlib import Path

import pandas as pd
import pyodbc


# Configuración

BASE_DIR = Path(__file__).resolve().parent
DATOS_DIR = BASE_DIR / "datos_generados"

SERVER = r"localhost\SQLEXPRESS"
DATABASE = "FINBANK"

CONNECTION_STRING = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
    "TrustServerCertificate=yes;"
)


# Conexión

print("Conectando a SQL Server...")

conexion = pyodbc.connect(CONNECTION_STRING)
cursor = conexion.cursor()

cursor.fast_executemany = True

print("Conexión exitosa a FINBANK.")


# Funciones

def leer_csv(nombre_archivo):
    ruta = DATOS_DIR / nombre_archivo

    if not ruta.exists():
        raise FileNotFoundError(
            f"No se encontró el archivo: {ruta}"
        )

    df = pd.read_csv(ruta)

    # Convierte valores NaN de pandas a None para SQL Server
    df = df.astype(object).where(pd.notnull(df), None)

    return df


def insertar_dataframe(tabla, df):
    columnas = list(df.columns)

    columnas_sql = ", ".join(
        f"[{columna}]" for columna in columnas
    )

    parametros = ", ".join(
        "?" for _ in columnas
    )

    sql = f"""
        INSERT INTO dbo.{tabla}
        ({columnas_sql})
        VALUES ({parametros})
    """

    registros = [
        tuple(fila)
        for fila in df.itertuples(index=False, name=None)
    ]

    cursor.executemany(sql, registros)

    print(
        f"{tabla}: {len(registros)} registros insertados."
    )


# Limpieza previa

print()
print("Limpiando tablas antes de cargar...")

# Primero se limpian las tablas relacionadas
cursor.execute("DELETE FROM dbo.TB_INCENTIVOS")
cursor.execute("DELETE FROM dbo.TB_COMISIONES_LOG")
cursor.execute("DELETE FROM dbo.TB_MOV_FINANCIEROS")
cursor.execute("DELETE FROM dbo.TB_OBLIGACIONES")

# Después las tablas principales
cursor.execute("DELETE FROM dbo.TB_SUCURSALES_RED")
cursor.execute("DELETE FROM dbo.TB_PRODUCTOS_CAT")
cursor.execute("DELETE FROM dbo.TB_CLIENTES_CORE")

conexion.commit()

print("Tablas limpiadas correctamente.")


# Lectura de archivos

print()
print("Leyendo archivos CSV...")

clientes = leer_csv("TB_CLIENTES_CORE.csv")
productos = leer_csv("TB_PRODUCTOS_CAT.csv")
sucursales = leer_csv("TB_SUCURSALES_RED.csv")
obligaciones = leer_csv("TB_OBLIGACIONES.csv")
movimientos = leer_csv("TB_MOV_FINANCIEROS.csv")
comisiones = leer_csv("TB_COMISIONES_LOG.csv")
incentivos = leer_csv("TB_INCENTIVOS.csv")


# Conversión de fechas

clientes["fec_nac"] = pd.to_datetime(
    clientes["fec_nac"]
).dt.date

clientes["fec_alta"] = pd.to_datetime(
    clientes["fec_alta"]
).dt.date

obligaciones["fec_desembolso"] = pd.to_datetime(
    obligaciones["fec_desembolso"]
).dt.date

obligaciones["fec_venc"] = pd.to_datetime(
    obligaciones["fec_venc"]
).dt.date

movimientos["fec_mov"] = pd.to_datetime(
    movimientos["fec_mov"]
).dt.date

comisiones["fec_cobro"] = pd.to_datetime(
    comisiones["fec_cobro"]
).dt.date

incentivos["fec_incentivo"] = pd.to_datetime(
    incentivos["fec_incentivo"]
).dt.date


# Carga a SQL Server

try:

    print()
    print("Iniciando carga a SQL Server...")
    print()

    # Primero se cargan las tablas principales
    insertar_dataframe(
        "TB_CLIENTES_CORE",
        clientes
    )

    insertar_dataframe(
        "TB_PRODUCTOS_CAT",
        productos
    )

    insertar_dataframe(
        "TB_SUCURSALES_RED",
        sucursales
    )

    # Después se cargan las tablas relacionadas
    insertar_dataframe(
        "TB_OBLIGACIONES",
        obligaciones
    )

    insertar_dataframe(
        "TB_MOV_FINANCIEROS",
        movimientos
    )

    insertar_dataframe(
        "TB_COMISIONES_LOG",
        comisiones
    )

    insertar_dataframe(
        "TB_INCENTIVOS",
        incentivos
    )

    conexion.commit()

    print()
    print("Carga terminada correctamente.")

except Exception as error:

    conexion.rollback()

    print()
    print("ERROR durante la carga:")
    print(error)

    raise


# Validación

print()
print("Validando registros en SQL Server...")
print()

tablas = [
    "TB_CLIENTES_CORE",
    "TB_PRODUCTOS_CAT",
    "TB_MOV_FINANCIEROS",
    "TB_OBLIGACIONES",
    "TB_SUCURSALES_RED",
    "TB_COMISIONES_LOG",
    "TB_INCENTIVOS"
]

for tabla in tablas:

    cursor.execute(
        f"SELECT COUNT(*) FROM dbo.{tabla}"
    )

    cantidad = cursor.fetchone()[0]

    print(
        f"{tabla}: {cantidad} registros"
    )


# Cierre

cursor.close()
conexion.close()

print()
print("Proceso finalizado.")
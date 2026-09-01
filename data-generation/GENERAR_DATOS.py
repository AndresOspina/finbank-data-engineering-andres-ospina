import json
import random
from datetime import datetime, timedelta
from pathlib import Path

import pandas as pd

BASE_DIR = Path(__file__).resolve().parent
CONFIG_PATH = BASE_DIR / "config.json"
SALIDA_DIR = BASE_DIR / "datos_generados"

SALIDA_DIR.mkdir(exist_ok=True)

with open(CONFIG_PATH, "r", encoding="utf-8") as archivo:
    config = json.load(archivo)

SEED = config["seed"]
random.seed(SEED)

ANOMALIAS = config["anomalias"]

FECHA_INICIO = datetime.strptime(
    config["fecha_inicio"], "%Y-%m-%d"
).date()

FECHA_FIN = datetime.strptime(
    config["fecha_fin"], "%Y-%m-%d"
).date()

VOLUMENES = config["volumenes"]

# ==========================================================
# DATOS BASE
# ==========================================================

nombres = [
    "Andres", "Laura", "Carlos", "Sofia", "Juan",
    "Camila", "Daniel", "Valentina", "Mateo", "Mariana",
    "Sebastian", "Natalia", "Felipe", "Paula", "David",
    "Daniela", "Alejandro", "Sara", "Miguel", "Juliana"
]

apellidos = [
    "Gomez", "Rodriguez", "Martinez", "Lopez", "Garcia",
    "Perez", "Ramirez", "Torres", "Diaz", "Castro",
    "Moreno", "Vargas", "Herrera", "Rojas", "Suarez",
    "Ortiz", "Mejia", "Cardona", "Restrepo", "Quintero"
]

ciudades = [
    ("Medellin", "Antioquia"),
    ("Bogota", "Cundinamarca"),
    ("Cali", "Valle del Cauca"),
    ("Barranquilla", "Atlantico"),
    ("Cartagena", "Bolivar")
]

segmentos = [
    "BASICO",
    "ESTANDAR",
    "PREMIUM",
    "ELITE"
]

canales = [
    "APP_MOVIL",
    "WEB",
    "CORRESPONSAL",
    "OFICINA"
]

# ==========================================================
# FUNCIONES
# ==========================================================

def fecha_aleatoria(inicio, fin):
    dias = (fin - inicio).days
    return inicio + timedelta(days=random.randint(0, dias))


def generar_clientes():
    registros = []

    for i in range(1, VOLUMENES["TB_CLIENTES_CORE"] + 1):

        ciudad, departamento = random.choice(ciudades)

        edad = random.randint(20, 70)

        fec_nac = FECHA_FIN.replace(
            year=FECHA_FIN.year - edad
        )

        registro = {
            "id_cli": i,
            "nomb_cli": nombres[(i - 1) % len(nombres)],
            "apell_cli": apellidos[(i - 1) % len(apellidos)],
            "tip_doc": random.choice(["CC", "CE"]),
            "num_doc": str(10000000 + i),
            "fec_nac": fec_nac,
            "fec_alta": fecha_aleatoria(FECHA_INICIO, FECHA_FIN),
            "cod_segmento": random.choice(segmentos),
            "score_buro": random.randint(450, 850),
            "ciudad_res": ciudad,
            "depto_res": departamento,
            "estado_cli": random.choice(
                ["ACTIVO", "ACTIVO", "ACTIVO", "INACTIVO"]
            ),
            "canal_adquis": random.choice(canales)
        }

        registros.append(registro)

    return pd.DataFrame(registros)


def generar_productos():
    registros = []

    tipos = [
        "CREDITO_LIBRE_INVERSION",
        "CREDITO_ROTATIVO",
        "TARJETA_DIGITAL",
        "CUENTA_AHORROS",
        "PSE",
        "TRANSFERENCIA_ACH"
    ]

    for i in range(1, VOLUMENES["TB_PRODUCTOS_CAT"] + 1):

        tipo = tipos[(i - 1) % len(tipos)]

        registro = {
            "cod_prod": f"PROD{i:03}",
            "desc_prod": f"Producto financiero {i}",
            "tip_prod": tipo,
            "tasa_ea": round(random.uniform(8, 35), 4),
            "plazo_max_meses": random.choice([12, 24, 36, 48, 60]),
            "cuota_min": round(random.uniform(50000, 300000), 2),
            "comision_admin": round(random.uniform(5000, 50000), 2),
            "estado_prod": "ACTIVO"
        }

        registros.append(registro)

    return pd.DataFrame(registros)


def generar_sucursales():
    registros = []

    for i in range(1, VOLUMENES["TB_SUCURSALES_RED"] + 1):

        ciudad, departamento = random.choice(ciudades)

        registro = {
            "cod_suc": f"SUC{i:03}",
            "nom_suc": f"Punto FinBank {i}",
            "tip_punto": random.choice(
                ["OFICINA", "CORRESPONSAL", "DIGITAL"]
            ),
            "ciudad": ciudad,
            "depto": departamento,
            "latitud": round(random.uniform(3.0, 11.0), 7),
            "longitud": round(random.uniform(-77.0, -73.0), 7),
            "activo": 1
        }

        registros.append(registro)

    return pd.DataFrame(registros)


def generar_obligaciones(clientes, productos):
    registros = []

    # Valores diseñados para cubrir todos los buckets de mora
    dias_mora = [
        0, 0, 0, 5, 10,
        15, 25, 30, 35, 45,
        55, 60, 65, 70, 80,
        90, 95, 110, 150, 200
    ]

    riesgos = [
        "A", "A", "A", "A", "B",
        "B", "B", "B", "C", "C",
        "C", "C", "D", "D", "D",
        "D", "E", "E", "E", "E"
    ]

    for i in range(1, VOLUMENES["TB_OBLIGACIONES"] + 1):

        cliente = clientes.iloc[(i - 1) % len(clientes)]
        producto = productos.iloc[(i - 1) % len(productos)]

        aprobado = random.randint(2_000_000, 80_000_000)
        desembolsado = aprobado * random.uniform(0.80, 1.00)
        saldo = desembolsado * random.uniform(0.10, 0.95)

        fec_desembolso = fecha_aleatoria(
            FECHA_INICIO,
            FECHA_FIN - timedelta(days=60)
        )

        plazo = random.choice([12, 24, 36, 48, 60])

        fec_venc = fec_desembolso + timedelta(days=plazo * 30)

        # Anomalía intencional #2:
        # obligación con fecha de vencimiento anterior al desembolso
        if ANOMALIAS["fecha_inconsistente_obligacion"] and i == 10:
             fec_venc = fec_desembolso - timedelta(days=30)

        registro = {
            "id_oblig": i,
            "id_cli": int(cliente["id_cli"]),
            "cod_prod": producto["cod_prod"],
            "vr_aprobado": round(aprobado, 2),
            "vr_desembolsado": round(desembolsado, 2),
            "sdo_capital": round(saldo, 2),
            "vr_cuota": round(desembolsado / plazo, 2),
            "fec_desembolso": fec_desembolso,
            "fec_venc": fec_venc,
            "dias_mora_act": dias_mora[(i - 1) % len(dias_mora)],
            "num_cuotas_pend": random.randint(1, plazo),
            "calif_riesgo": riesgos[(i - 1) % len(riesgos)]
        }

        registros.append(registro)

    return pd.DataFrame(registros)


def generar_movimientos(clientes, productos):
    registros = []

    montos_normales = [
        50000,
        70000,
        90000,
        120000,
        150000,
        180000
    ]

    # Usaremos 5 clientes con 4 movimientos cada uno
    clientes_fraude = clientes.iloc[:5]

    movimiento_id = 1

    for _, cliente in clientes_fraude.iterrows():

        producto = productos.iloc[
            (int(cliente["id_cli"]) - 1) % len(productos)
        ]

        # 4 movimientos por cliente
        for j in range(4):

            # Cliente 5:
            # movimientos dentro de los últimos 30 días
            if int(cliente["id_cli"]) == 5:
                fechas_cliente_5 = [
                    FECHA_FIN - timedelta(days=22),
                    FECHA_FIN - timedelta(days=15),
                    FECHA_FIN - timedelta(days=7),
                    FECHA_FIN
                ]
                fecha = fechas_cliente_5[j]
            else:
                fecha = fecha_aleatoria(
                    FECHA_INICIO,
                    FECHA_FIN
                )

            hora = random.choice([
                "08:15:00",
                "10:30:00",
                "12:45:00",
                "15:20:00",
                "18:10:00",
                "20:30:00"
            ])

            monto = random.choice(montos_normales)

            # Los 3 primeros movimientos del cliente 5
            # tendrán el mismo comportamiento histórico
            if int(cliente["id_cli"]) == 5 and j < 3:
                monto = 180_000

            # Anomalía intencional:
            # cuarto movimiento del cliente 5
            if (
                ANOMALIAS["movimiento_atipico"]
                and int(cliente["id_cli"]) == 5
                and j == 3
            ):
                monto = 8_500_000
                hora = "02:35:00"
                fecha = FECHA_FIN

            registro = {
                "id_mov": movimiento_id,
                "id_cli": int(cliente["id_cli"]),
                "cod_prod": producto["cod_prod"],
                "num_cuenta": f"CTA{int(cliente['id_cli']):06}",
                "fec_mov": fecha,
                "hra_mov": hora,
                "vr_mov": monto,
                "tip_mov": random.choice([
                    "PAGO",
                    "TRANSFERENCIA",
                    "COMPRA",
                    "RETIRO"
                ]),
                "cod_canal": random.choice([
                    "APP",
                    "WEB",
                    "PSE",
                    "CORRESPONSAL"
                ]),
                "cod_ciudad": cliente["ciudad_res"],
                "cod_estado_mov": "APROBADO",
                "id_dispositivo": f"DEV-{int(cliente['id_cli']):04}"
            }

            # Anomalía intencional #3:
            # duplicado lógico con id_mov diferente
            if (
                ANOMALIAS["duplicado_logico_movimiento"]
                and movimiento_id == 19
                and len(registros) > 0
            ):
                registro_duplicado = registros[-1].copy()
                registro_duplicado["id_mov"] = movimiento_id
                registro = registro_duplicado

            registros.append(registro)
            movimiento_id += 1

    return pd.DataFrame(registros)


def generar_comisiones(clientes, productos):
    registros = []

    for i in range(1, VOLUMENES["TB_COMISIONES_LOG"] + 1):

        cliente = clientes.iloc[(i - 1) % len(clientes)]
        producto = productos.iloc[(i - 1) % len(productos)]

        registro = {
            "id_comision": i,
            "id_cli": int(cliente["id_cli"]),
            "cod_prod": producto["cod_prod"],
            "fec_cobro": fecha_aleatoria(FECHA_INICIO, FECHA_FIN),
            "vr_comision": round(random.uniform(5000, 80000), 2),
            "tip_comision": random.choice(
                [
                    "ADMINISTRACION",
                    "TRANSACCION",
                    "MANEJO"
                ]
            ),
            "estado_cobro": random.choice(
                [
                    "COBRADA",
                    "COBRADA",
                    "COBRADA",
                    "PENDIENTE"
                ]
            )
        }

        registros.append(registro)

    return pd.DataFrame(registros)

def generar_incentivos(clientes, productos):
    registros = []

    tipos_incentivo = [
        "CASHBACK",
        "BONO_BIENVENIDA",
        "FIDELIZACION",
        "PROMOCION"
    ]

    for i in range(1, VOLUMENES["TB_INCENTIVOS"] + 1):

        cliente = clientes.iloc[(i - 1) % len(clientes)]
        producto = productos.iloc[(i - 1) % len(productos)]

        registro = {
            "id_incentivo": i,
            "id_cli": int(cliente["id_cli"]),
            "cod_prod": producto["cod_prod"],
            "fec_incentivo": fecha_aleatoria(
                FECHA_INICIO,
                FECHA_FIN
            ),
            "tip_incentivo": random.choice(
                tipos_incentivo
            ),
            "vr_incentivo": round(
                random.uniform(5000, 50000),
                2
            ),
            "estado_incentivo": random.choice(
                [
                    "OTORGADO",
                    "OTORGADO",
                    "OTORGADO",
                    "CANCELADO"
                ]
            )
        }

        registros.append(registro)

    return pd.DataFrame(registros)


def aplicar_nulos_controlados(clientes, productos, movimientos, obligaciones, sucursales):

    # Aproximadamente 5% para 20 registros = 1 registro.
    clientes.loc[0, "score_buro"] = None
    clientes.loc[1, "canal_adquis"] = None

    productos.loc[0, "comision_admin"] = None

    movimientos.loc[1, "id_dispositivo"] = None

    obligaciones.loc[1, "calif_riesgo"] = None

    sucursales.loc[0, "latitud"] = None


def guardar_dataframe(df, nombre):

    csv_path = SALIDA_DIR / f"{nombre}.csv"
    json_path = SALIDA_DIR / f"{nombre}.json"

    df.to_csv(
        csv_path,
        index=False,
        encoding="utf-8-sig"
    )

    df.to_json(
        json_path,
        orient="records",
        force_ascii=False,
        indent=2,
        date_format="iso"
    )


# ==========================================================
# EJECUCIÓN
# ==========================================================

print("Generando datos FinBank...")

clientes = generar_clientes()

productos = generar_productos()

sucursales = generar_sucursales()

obligaciones = generar_obligaciones(
    clientes,
    productos
)

movimientos = generar_movimientos(
    clientes,
    productos
)

comisiones = generar_comisiones(
    clientes,
    productos
)

incentivos = generar_incentivos(
    clientes,
    productos
)

aplicar_nulos_controlados(
    clientes,
    productos,
    movimientos,
    obligaciones,
    sucursales
)

guardar_dataframe(
    clientes,
    "TB_CLIENTES_CORE"
)

guardar_dataframe(
    productos,
    "TB_PRODUCTOS_CAT"
)

guardar_dataframe(
    movimientos,
    "TB_MOV_FINANCIEROS"
)

guardar_dataframe(
    obligaciones,
    "TB_OBLIGACIONES"
)

guardar_dataframe(
    sucursales,
    "TB_SUCURSALES_RED"
)

guardar_dataframe(
    comisiones,
    "TB_COMISIONES_LOG"
)

guardar_dataframe(
    incentivos,
    "TB_INCENTIVOS"
)

print()
print("Generación terminada correctamente.")
print()

print("Registros generados:")
print("TB_CLIENTES_CORE:", len(clientes))
print("TB_PRODUCTOS_CAT:", len(productos))
print("TB_MOV_FINANCIEROS:", len(movimientos))
print("TB_OBLIGACIONES:", len(obligaciones))
print("TB_SUCURSALES_RED:", len(sucursales))
print("TB_COMISIONES_LOG:", len(comisiones))
print("TB_INCENTIVOS:", len(incentivos))

print()
print("Archivos guardados en:")
print(SALIDA_DIR)
USE FINBANK;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='gold')
    EXEC('CREATE SCHEMA gold');
GO

-- Reconstruccion idempotente de Gold
DROP TABLE IF EXISTS gold.fact_movimientos;
DROP TABLE IF EXISTS gold.vista_cliente_360;
DROP TABLE IF EXISTS gold.reporte_regulatorio;
DROP TABLE IF EXISTS gold.kpi_cartera_diaria;
DROP TABLE IF EXISTS gold.fact_rentabilidad_cliente;
DROP TABLE IF EXISTS gold.fact_cartera;
DROP TABLE IF EXISTS gold.fact_transacciones;
DROP TABLE IF EXISTS gold.dim_clientes;
DROP TABLE IF EXISTS gold.dim_productos;
DROP TABLE IF EXISTS gold.dim_geografia;
DROP TABLE IF EXISTS gold.dim_canal;
GO

-- DIMENSION CLIENTES
SELECT
    CAST(ROW_NUMBER() OVER(ORDER BY id_cli) AS BIGINT) cliente_key,
    id_cli,
    nombre_completo,
    tip_doc,
    num_doc_enmascarado,
    fec_nac,
    edad,
    fec_alta,
    cod_segmento,
    segmento_legible,
    score_buro,
    ciudad_res,
    depto_res,
    estado_cli,
    canal_adquis
INTO gold.dim_clientes
FROM silver.clientes;

ALTER TABLE gold.dim_clientes
ALTER COLUMN cliente_key BIGINT NOT NULL;

ALTER TABLE gold.dim_clientes
ADD CONSTRAINT PK_dim_clientes
PRIMARY KEY(cliente_key);
GO


-- DIMENSION PRODUCTOS
SELECT
    CAST(ROW_NUMBER() OVER(ORDER BY cod_prod) AS BIGINT) producto_key,
    cod_prod,
    nombre_producto,
    tipo_producto,
    tasa_ea,
    tasa_mensual_equivalente,
    plazo_max_meses,
    cuota_min,
    comision_admin,
    estado_prod,
    familia_producto
INTO gold.dim_productos
FROM silver.productos;

ALTER TABLE gold.dim_productos
ALTER COLUMN producto_key BIGINT NOT NULL;

ALTER TABLE gold.dim_productos
ADD CONSTRAINT PK_dim_productos
PRIMARY KEY(producto_key);
GO


-- DIMENSION GEOGRAFIA
SELECT
    CAST(
        ROW_NUMBER() OVER(ORDER BY ciudad_res, depto_res)
        AS BIGINT
    ) geografia_key,
    ciudad_res AS ciudad,
    depto_res AS departamento
INTO gold.dim_geografia
FROM silver.clientes
WHERE ciudad_res IS NOT NULL
  AND depto_res IS NOT NULL
GROUP BY ciudad_res, depto_res;

ALTER TABLE gold.dim_geografia
ALTER COLUMN geografia_key BIGINT NOT NULL;

ALTER TABLE gold.dim_geografia
ADD CONSTRAINT PK_dim_geografia
PRIMARY KEY(geografia_key);
GO


-- DIMENSION CANAL
SELECT
    CAST(ROW_NUMBER() OVER(ORDER BY cod_canal) AS BIGINT) canal_key,
    cod_canal
INTO gold.dim_canal
FROM silver.movimientos
WHERE cod_canal IS NOT NULL
GROUP BY cod_canal;

ALTER TABLE gold.dim_canal
ALTER COLUMN canal_key BIGINT NOT NULL;

ALTER TABLE gold.dim_canal
ADD CONSTRAINT PK_dim_canal
PRIMARY KEY(canal_key);
GO


-- FACT TRANSACCIONES
DECLARE @trm DECIMAL(18,4) = 4000.00;

SELECT
    CAST(ROW_NUMBER() OVER(ORDER BY m.id_mov) AS BIGINT) transaccion_key,
    m.id_mov,
    c.cliente_key,
    p.producto_key,
    ca.canal_key,
    g.geografia_key,
    m.fec_mov,
    m.hra_mov,
    m.num_cuenta,
    m.vr_mov AS monto_cop,
    CAST(m.vr_mov / @trm AS DECIMAL(18,2)) AS monto_usd,
    m.tip_mov,
    m.cod_estado_mov,
    m.id_dispositivo,
    m.movimientos_previos,
    m.promedio_historico,
    m.desviacion_historica,
    m.frecuencia_diaria,
    m.alerta_monto,
    m.alerta_horario,
    m.alerta_frecuencia,
    m.alerta_canal,
    m.total_alertas,
    m.ind_sospechoso
INTO gold.fact_transacciones
FROM silver.movimientos m
INNER JOIN gold.dim_clientes c
    ON m.id_cli = c.id_cli
INNER JOIN gold.dim_productos p
    ON m.cod_prod = p.cod_prod
LEFT JOIN gold.dim_canal ca
    ON m.cod_canal = ca.cod_canal
LEFT JOIN gold.dim_geografia g
    ON m.cod_ciudad = g.ciudad;

ALTER TABLE gold.fact_transacciones
ALTER COLUMN transaccion_key BIGINT NOT NULL;

ALTER TABLE gold.fact_transacciones
ADD
    CONSTRAINT PK_fact_transacciones
        PRIMARY KEY(transaccion_key),

    CONSTRAINT FK_fact_transacciones_dim_clientes
        FOREIGN KEY(cliente_key)
        REFERENCES gold.dim_clientes(cliente_key),

    CONSTRAINT FK_fact_transacciones_dim_productos
        FOREIGN KEY(producto_key)
        REFERENCES gold.dim_productos(producto_key),

    CONSTRAINT FK_fact_transacciones_dim_canal
        FOREIGN KEY(canal_key)
        REFERENCES gold.dim_canal(canal_key),

    CONSTRAINT FK_fact_transacciones_dim_geografia
        FOREIGN KEY(geografia_key)
        REFERENCES gold.dim_geografia(geografia_key);
GO


-- FACT CARTERA
SELECT
    CAST(ROW_NUMBER() OVER(ORDER BY o.id_oblig) AS BIGINT) cartera_key,
    o.id_oblig,
    c.cliente_key,
    p.producto_key,
    o.vr_aprobado,
    o.vr_desembolsado,
    o.sdo_capital,
    o.vr_cuota,
    o.fec_desembolso,
    o.fec_venc,
    o.dias_mora_act,
    o.num_cuotas_pend,
    o.bucket_mora,
    o.calif_riesgo,

    CASE
        WHEN o.dias_mora_act = 0 THEN 'A'
        WHEN o.dias_mora_act <= 30 THEN 'B'
        WHEN o.dias_mora_act <= 60 THEN 'C'
        WHEN o.dias_mora_act <= 90 THEN 'D'
        ELSE 'E'
    END AS clasificacion_regulatoria,

    CAST(
        CASE
            WHEN o.dias_mora_act = 0 THEN 0.01
            WHEN o.dias_mora_act <= 30 THEN 0.05
            WHEN o.dias_mora_act <= 60 THEN 0.20
            WHEN o.dias_mora_act <= 90 THEN 0.50
            ELSE 1.00
        END
        AS DECIMAL(5,2)
    ) AS porcentaje_provision,

    CAST(
        o.sdo_capital *
        CASE
            WHEN o.dias_mora_act = 0 THEN 0.01
            WHEN o.dias_mora_act <= 30 THEN 0.05
            WHEN o.dias_mora_act <= 60 THEN 0.20
            WHEN o.dias_mora_act <= 90 THEN 0.50
            ELSE 1.00
        END
        AS DECIMAL(18,2)
    ) AS provision_estimada

INTO gold.fact_cartera
FROM silver.obligaciones o
INNER JOIN gold.dim_clientes c
    ON o.id_cli = c.id_cli
INNER JOIN gold.dim_productos p
    ON o.cod_prod = p.cod_prod
WHERE o.estado_calidad = 'VALIDO';

ALTER TABLE gold.fact_cartera
ALTER COLUMN cartera_key BIGINT NOT NULL;

ALTER TABLE gold.fact_cartera
ADD
    CONSTRAINT PK_fact_cartera
        PRIMARY KEY(cartera_key),

    CONSTRAINT FK_fact_cartera_dim_clientes
        FOREIGN KEY(cliente_key)
        REFERENCES gold.dim_clientes(cliente_key),

    CONSTRAINT FK_fact_cartera_dim_productos
        FOREIGN KEY(producto_key)
        REFERENCES gold.dim_productos(producto_key);
GO


-- RENTABILIDAD / CLTV 12 MESES
DECLARE @fecha_corte DATE = '2026-08-27';

WITH meses AS
(
    SELECT DATEADD(
        MONTH,
        -11,
        DATEFROMPARTS(
            YEAR(@fecha_corte),
            MONTH(@fecha_corte),
            1
        )
    ) AS mes_inicio

    UNION ALL

    SELECT DATEADD(MONTH, 1, mes_inicio)
    FROM meses
    WHERE mes_inicio <
        DATEFROMPARTS(
            YEAR(@fecha_corte),
            MONTH(@fecha_corte),
            1
        )
)

SELECT
    CAST(
        ROW_NUMBER() OVER(
            ORDER BY c.cliente_key, m.mes_inicio
        )
        AS BIGINT
    ) AS rentabilidad_key,

    c.cliente_key,
    m.mes_inicio,

    CAST(
        ISNULL(i.ingreso_intereses, 0)
        AS DECIMAL(18,2)
    ) AS ingreso_intereses,

    CAST(
        ISNULL(co.comisiones_cobradas, 0)
        AS DECIMAL(18,2)
    ) AS comisiones_cobradas,

    CAST(
        ISNULL(inc.costo_incentivos, 0)
        AS DECIMAL(18,2)
    ) AS costo_incentivos,

    CAST(
        ISNULL(i.ingreso_intereses, 0)
        + ISNULL(co.comisiones_cobradas, 0)
        AS DECIMAL(18,2)
    ) AS cltv_mensual

INTO gold.fact_rentabilidad_cliente

FROM gold.dim_clientes c

CROSS JOIN meses m

OUTER APPLY
(
    SELECT
        SUM(
            o.sdo_capital
            * (ISNULL(p.tasa_ea, 0) / 100.0)
            / 12.0
        ) AS ingreso_intereses

    FROM silver.obligaciones o

    LEFT JOIN silver.productos p
        ON o.cod_prod = p.cod_prod

    WHERE o.id_cli = c.id_cli
      AND o.estado_calidad = 'VALIDO'
      AND o.fec_desembolso <= EOMONTH(m.mes_inicio)
      AND o.fec_venc >= m.mes_inicio
) i

OUTER APPLY
(
    SELECT
        SUM(sc.vr_comision) AS comisiones_cobradas

    FROM silver.comisiones sc

    WHERE sc.id_cli = c.id_cli
      AND sc.ind_comision_cobrada = 1
      AND DATEFROMPARTS(
            YEAR(sc.fec_cobro),
            MONTH(sc.fec_cobro),
            1
          ) = m.mes_inicio
) co

OUTER APPLY
(
    SELECT
        SUM(si.vr_incentivo) AS costo_incentivos

    FROM silver.incentivos si

    WHERE si.id_cli = c.id_cli
      AND si.ind_incentivo_otorgado = 1
      AND DATEFROMPARTS(
            YEAR(si.fec_incentivo),
            MONTH(si.fec_incentivo),
            1
          ) = m.mes_inicio
) inc

OPTION(MAXRECURSION 12);

ALTER TABLE gold.fact_rentabilidad_cliente
ALTER COLUMN rentabilidad_key BIGINT NOT NULL;

ALTER TABLE gold.fact_rentabilidad_cliente
ADD
    CONSTRAINT PK_fact_rentabilidad_cliente
        PRIMARY KEY(rentabilidad_key),

    CONSTRAINT FK_fact_rentabilidad_dim_clientes
        FOREIGN KEY(cliente_key)
        REFERENCES gold.dim_clientes(cliente_key);
GO


-- KPI DIARIO DE CARTERA
DECLARE @fecha_kpi DATE = '2026-08-27';

SELECT
    @fecha_kpi AS fecha_kpi,
    fc.producto_key,
    dc.segmento_legible AS segmento,
    dc.ciudad_res AS ciudad,

    COUNT(*) AS total_obligaciones_activas,

    CAST(
        SUM(fc.sdo_capital)
        AS DECIMAL(18,2)
    ) AS cartera_total,

    CAST(
        SUM(
            CASE
                WHEN fc.dias_mora_act > 0
                    THEN fc.sdo_capital
                ELSE 0
            END
        )
        AS DECIMAL(18,2)
    ) AS monto_en_mora,

    CAST(
        CASE
            WHEN SUM(fc.sdo_capital) = 0 THEN 0
            ELSE
                SUM(
                    CASE
                        WHEN fc.dias_mora_act > 0
                            THEN fc.sdo_capital
                        ELSE 0
                    END
                ) * 100.0 / SUM(fc.sdo_capital)
        END
        AS DECIMAL(10,2)
    ) AS tasa_mora_pct,

    COUNT(
        DISTINCT
        CASE
            WHEN fc.dias_mora_act > 0
                THEN fc.cliente_key
        END
    ) AS clientes_en_mora

INTO gold.kpi_cartera_diaria

FROM gold.fact_cartera fc

INNER JOIN gold.dim_clientes dc
    ON fc.cliente_key = dc.cliente_key

GROUP BY
    fc.producto_key,
    dc.segmento_legible,
    dc.ciudad_res;
GO


-- REPORTE REGULATORIO
WITH cuentas AS
(
    SELECT
        fc.producto_key,
        dc.segmento_legible AS segmento,
        dc.ciudad_res AS ciudad,
        COUNT(DISTINCT fc.cliente_key) AS cuentas_activas

    FROM gold.fact_cartera fc

    INNER JOIN gold.dim_clientes dc
        ON fc.cliente_key = dc.cliente_key

    GROUP BY
        fc.producto_key,
        dc.segmento_legible,
        dc.ciudad_res
),

transacciones AS
(
    SELECT
        ft.fec_mov AS fecha,
        ft.producto_key,
        dc.segmento_legible AS segmento,
        dg.ciudad,
        dc.canal_adquis AS canal,

        COUNT(*) AS total_transacciones,

        CAST(
            SUM(ft.monto_cop)
            AS DECIMAL(18,2)
        ) AS volumen_transaccional

    FROM gold.fact_transacciones ft

    INNER JOIN gold.dim_clientes dc
        ON ft.cliente_key = dc.cliente_key

    LEFT JOIN gold.dim_geografia dg
        ON ft.geografia_key = dg.geografia_key

    GROUP BY
        ft.fec_mov,
        ft.producto_key,
        dc.segmento_legible,
        dg.ciudad,
        dc.canal_adquis
)

SELECT
    t.fecha,
    t.producto_key,
    t.segmento,
    t.ciudad,
    t.canal,
    ISNULL(c.cuentas_activas, 0) AS cuentas_activas,
    t.total_transacciones,
    t.volumen_transaccional

INTO gold.reporte_regulatorio

FROM transacciones t

LEFT JOIN cuentas c
    ON t.producto_key = c.producto_key
   AND t.segmento = c.segmento
   AND t.ciudad = c.ciudad;
GO


-- CLIENTE 360
WITH cartera AS
(
    SELECT
        cliente_key,
        COUNT(*) AS total_obligaciones,
        COUNT(DISTINCT producto_key) AS productos_cartera,

        CAST(
            SUM(sdo_capital)
            AS DECIMAL(18,2)
        ) AS saldo_total_capital,

        MAX(dias_mora_act) AS max_dias_mora,

        CASE
            WHEN MAX(dias_mora_act) = 0 THEN 'AL DIA'
            WHEN MAX(dias_mora_act) <= 30 THEN 'RANGO 1'
            WHEN MAX(dias_mora_act) <= 60 THEN 'RANGO 2'
            WHEN MAX(dias_mora_act) <= 90 THEN 'RANGO 3'
            ELSE 'DETERIORADO'
        END AS estado_mora,

        MAX(clasificacion_regulatoria)
            AS clasificacion_riesgo

    FROM gold.fact_cartera

    GROUP BY cliente_key
),

movimientos AS
(
    SELECT
        cliente_key,
        COUNT(*) AS total_movimientos,
        COUNT(DISTINCT producto_key)
            AS productos_transaccionales,

        CAST(
            SUM(monto_cop)
            AS DECIMAL(18,2)
        ) AS volumen_movimientos,

        SUM(
            CASE
                WHEN ind_sospechoso = 1 THEN 1
                ELSE 0
            END
        ) AS movimientos_sospechosos

    FROM gold.fact_transacciones

    GROUP BY cliente_key
),

rentabilidad AS
(
    SELECT
        cliente_key,

        CAST(
            SUM(ingreso_intereses)
            AS DECIMAL(18,2)
        ) AS ingresos_intereses_12m,

        CAST(
            SUM(comisiones_cobradas)
            AS DECIMAL(18,2)
        ) AS comisiones_cobradas_12m,

        CAST(
            SUM(costo_incentivos)
            AS DECIMAL(18,2)
        ) AS incentivos_12m,

        CAST(
            SUM(cltv_mensual)
            AS DECIMAL(18,2)
        ) AS cltv_12m

    FROM gold.fact_rentabilidad_cliente

    GROUP BY cliente_key
)

SELECT
    c.cliente_key,
    c.id_cli,
    c.nombre_completo,
    c.segmento_legible AS segmento,
    c.ciudad_res AS ciudad,
    c.depto_res AS departamento,
    c.score_buro,
    c.estado_cli,

    ISNULL(car.total_obligaciones, 0)
        AS total_obligaciones,

    ISNULL(car.productos_cartera, 0)
        + ISNULL(mov.productos_transaccionales, 0)
        AS productos_utilizados,

    ISNULL(mov.total_movimientos, 0)
        AS total_movimientos,

    ISNULL(car.saldo_total_capital, 0)
        AS saldo_total_capital,

    ISNULL(car.max_dias_mora, 0)
        AS max_dias_mora,

    ISNULL(car.estado_mora, 'AL DIA')
        AS estado_mora,

    car.clasificacion_riesgo,

    ISNULL(mov.volumen_movimientos, 0)
        AS volumen_movimientos,

    ISNULL(mov.movimientos_sospechosos, 0)
        AS movimientos_sospechosos,

    ISNULL(r.ingresos_intereses_12m, 0)
        AS ingresos_intereses_12m,

    ISNULL(r.comisiones_cobradas_12m, 0)
        AS comisiones_cobradas_12m,

    ISNULL(r.incentivos_12m, 0)
        AS incentivos_12m,

    ISNULL(r.cltv_12m, 0)
        AS cltv_12m

INTO gold.vista_cliente_360

FROM gold.dim_clientes c

LEFT JOIN cartera car
    ON c.cliente_key = car.cliente_key

LEFT JOIN movimientos mov
    ON c.cliente_key = mov.cliente_key

LEFT JOIN rentabilidad r
    ON c.cliente_key = r.cliente_key;
GO


-- INDICES
CREATE NONCLUSTERED INDEX
IX_fact_transacciones_fecha_cliente_producto
ON gold.fact_transacciones
(
    fec_mov,
    cliente_key,
    producto_key
)
INCLUDE
(
    monto_cop,
    ind_sospechoso
);

CREATE NONCLUSTERED INDEX
IX_fact_cartera_cliente_producto_mora
ON gold.fact_cartera
(
    cliente_key,
    producto_key,
    dias_mora_act
)
INCLUDE
(
    sdo_capital,
    clasificacion_regulatoria,
    porcentaje_provision,
    provision_estimada
);

CREATE NONCLUSTERED INDEX
IX_fact_rentabilidad_cliente_mes
ON gold.fact_rentabilidad_cliente
(
    cliente_key,
    mes_inicio
)
INCLUDE
(
    ingreso_intereses,
    comisiones_cobradas,
    costo_incentivos,
    cltv_mensual
);
GO
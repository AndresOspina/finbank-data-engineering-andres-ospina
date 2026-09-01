USE FINBANK;
GO

-- BRONZE
SELECT objeto, registros
FROM (
    SELECT 'TB_CLIENTES_CORE' objeto, COUNT(*) registros FROM bronze.TB_CLIENTES_CORE
    UNION ALL SELECT 'TB_PRODUCTOS_CAT', COUNT(*) FROM bronze.TB_PRODUCTOS_CAT
    UNION ALL SELECT 'TB_SUCURSALES_RED', COUNT(*) FROM bronze.TB_SUCURSALES_RED
    UNION ALL SELECT 'TB_OBLIGACIONES', COUNT(*) FROM bronze.TB_OBLIGACIONES
    UNION ALL SELECT 'TB_MOV_FINANCIEROS', COUNT(*) FROM bronze.TB_MOV_FINANCIEROS
    UNION ALL SELECT 'TB_COMISIONES_LOG', COUNT(*) FROM bronze.TB_COMISIONES_LOG
    UNION ALL SELECT 'TB_INCENTIVOS', COUNT(*) FROM bronze.TB_INCENTIVOS
) x
ORDER BY objeto;
GO

-- SILVER: calidad
SELECT
    tabla,
    registros_bronze,
    registros_silver,
    registros_rechazados,
    porcentaje_conformidad
FROM silver.reporte_calidad
ORDER BY tabla;
GO

-- REGISTROS RECHAZADOS
SELECT
    id_oblig,
    id_cli,
    tipo_error,
    motivo_rechazo
FROM silver.obligaciones_rechazadas;
GO

-- TRANSACCIONES SOSPECHOSAS
SELECT
    id_mov,
    id_cli,
    vr_mov AS monto,
    total_alertas,
    ind_sospechoso
FROM silver.movimientos
WHERE ind_sospechoso = 1;
GO

-- GOLD: objetos principales
SELECT objeto, registros
FROM (
    SELECT 'dim_clientes' objeto, COUNT(*) registros FROM gold.dim_clientes
    UNION ALL SELECT 'dim_productos', COUNT(*) FROM gold.dim_productos
    UNION ALL SELECT 'dim_geografia', COUNT(*) FROM gold.dim_geografia
    UNION ALL SELECT 'dim_canal', COUNT(*) FROM gold.dim_canal
    UNION ALL SELECT 'fact_transacciones', COUNT(*) FROM gold.fact_transacciones
    UNION ALL SELECT 'fact_cartera', COUNT(*) FROM gold.fact_cartera
    UNION ALL SELECT 'fact_rentabilidad_cliente', COUNT(*) FROM gold.fact_rentabilidad_cliente
    UNION ALL SELECT 'kpi_cartera_diaria', COUNT(*) FROM gold.kpi_cartera_diaria
    UNION ALL SELECT 'reporte_regulatorio', COUNT(*) FROM gold.reporte_regulatorio
    UNION ALL SELECT 'vista_cliente_360', COUNT(*) FROM gold.vista_cliente_360
) x
ORDER BY objeto;
GO

-- GOLD: transacciones y fraude
SELECT
    COUNT(*) total_transacciones,
    SUM(CASE WHEN ind_sospechoso = 1 THEN 1 ELSE 0 END) sospechosas,
    SUM(CASE WHEN cliente_key IS NULL THEN 1 ELSE 0 END) clientes_sin_relacion,
    SUM(CASE WHEN producto_key IS NULL THEN 1 ELSE 0 END) productos_sin_relacion,
    SUM(CASE WHEN canal_key IS NULL THEN 1 ELSE 0 END) canales_sin_relacion,
    SUM(CASE WHEN geografia_key IS NULL THEN 1 ELSE 0 END) geografias_sin_relacion,
    CAST(SUM(monto_cop) AS DECIMAL(18,2)) volumen_cop,
    CAST(SUM(monto_usd) AS DECIMAL(18,2)) volumen_usd
FROM gold.fact_transacciones;
GO

-- CARTERA
SELECT
    COUNT(*) total_cartera,
    SUM(CASE WHEN clasificacion_regulatoria IS NULL
              OR porcentaje_provision IS NULL
              OR provision_estimada IS NULL THEN 1 ELSE 0 END) nulos_criticos,
    SUM(CASE WHEN clasificacion_regulatoria = 'A' THEN 1 ELSE 0 END) clase_A,
    SUM(CASE WHEN clasificacion_regulatoria = 'B' THEN 1 ELSE 0 END) clase_B,
    SUM(CASE WHEN clasificacion_regulatoria = 'C' THEN 1 ELSE 0 END) clase_C,
    SUM(CASE WHEN clasificacion_regulatoria = 'D' THEN 1 ELSE 0 END) clase_D,
    SUM(CASE WHEN clasificacion_regulatoria = 'E' THEN 1 ELSE 0 END) clase_E
FROM gold.fact_cartera;
GO

-- CLTV
SELECT
    COUNT(*) total_registros,
    COUNT(DISTINCT cliente_key) clientes,
    MIN(mes_inicio) primer_mes,
    MAX(mes_inicio) ultimo_mes,
    SUM(CASE WHEN ABS(
        cltv_mensual - (ISNULL(ingreso_intereses,0) + ISNULL(comisiones_cobradas,0))
    ) > 0.01 THEN 1 ELSE 0 END) cltv_incorrectos
FROM gold.fact_rentabilidad_cliente;
GO

-- KPI CARTERA
SELECT
    COUNT(*) total_kpis,
    SUM(total_obligaciones_activas) obligaciones_consolidadas,
    SUM(clientes_en_mora) clientes_en_mora
FROM gold.kpi_cartera_diaria;
GO

-- REPORTE REGULATORIO
SELECT
    SUM(total_transacciones) transacciones,
    CAST(SUM(volumen_transaccional) AS DECIMAL(18,2)) volumen_total,
    SUM(cuentas_activas) cuentas_activas
FROM gold.reporte_regulatorio;
GO

-- CLIENTE 360
SELECT
    COUNT(*) total_clientes,
    COUNT(DISTINCT cliente_key) clientes_unicos
FROM gold.vista_cliente_360;
GO

-- DUPLICADOS GOLD
SELECT objeto, duplicados
FROM (
    SELECT 'dim_clientes' objeto, COUNT(*) duplicados
    FROM (
        SELECT cliente_key FROM gold.dim_clientes
        GROUP BY cliente_key HAVING COUNT(*) > 1
    ) x
    UNION ALL
    SELECT 'dim_productos', COUNT(*)
    FROM (
        SELECT producto_key FROM gold.dim_productos
        GROUP BY producto_key HAVING COUNT(*) > 1
    ) x
    UNION ALL
    SELECT 'fact_transacciones', COUNT(*)
    FROM (
        SELECT transaccion_key FROM gold.fact_transacciones
        GROUP BY transaccion_key HAVING COUNT(*) > 1
    ) x
    UNION ALL
    SELECT 'fact_cartera', COUNT(*)
    FROM (
        SELECT cartera_key FROM gold.fact_cartera
        GROUP BY cartera_key HAVING COUNT(*) > 1
    ) x
) d;
GO

-- INTEGRIDAD REFERENCIAL
SELECT
    SUM(CASE WHEN dc.cliente_key IS NULL THEN 1 ELSE 0 END) clientes_huerfanos,
    SUM(CASE WHEN dp.producto_key IS NULL THEN 1 ELSE 0 END) productos_huerfanos,
    SUM(CASE WHEN ca.canal_key IS NULL THEN 1 ELSE 0 END) canales_huerfanos,
    SUM(CASE WHEN dg.geografia_key IS NULL THEN 1 ELSE 0 END) geografias_huerfanas
FROM gold.fact_transacciones ft
LEFT JOIN gold.dim_clientes dc ON ft.cliente_key = dc.cliente_key
LEFT JOIN gold.dim_productos dp ON ft.producto_key = dp.producto_key
LEFT JOIN gold.dim_canal ca ON ft.canal_key = ca.canal_key
LEFT JOIN gold.dim_geografia dg ON ft.geografia_key = dg.geografia_key;
GO

-- MOVIMIENTOS, si existe
IF OBJECT_ID('gold.fact_movimientos','U') IS NOT NULL
SELECT
    COUNT(*) total_movimientos,
    SUM(CASE WHEN dc.cliente_key IS NULL THEN 1 ELSE 0 END) clientes_huerfanos,
    SUM(CASE WHEN dp.producto_key IS NULL THEN 1 ELSE 0 END) productos_huerfanos,
    SUM(CASE WHEN ca.canal_key IS NULL THEN 1 ELSE 0 END) canales_huerfanos,
    SUM(CASE WHEN dg.geografia_key IS NULL THEN 1 ELSE 0 END) geografias_huerfanas
FROM gold.fact_movimientos fm
LEFT JOIN gold.dim_clientes dc ON fm.cliente_key = dc.cliente_key
LEFT JOIN gold.dim_productos dp ON fm.producto_key = dp.producto_key
LEFT JOIN gold.dim_canal ca ON fm.canal_key = ca.canal_key
LEFT JOIN gold.dim_geografia dg ON fm.geografia_key = dg.geografia_key;
GO

-- PRUEBAS AUTOMATICAS
IF OBJECT_ID('dbo.RESULTADO_PRUEBAS_CALIDAD','U') IS NULL
CREATE TABLE dbo.RESULTADO_PRUEBAS_CALIDAD(
    id_resultado BIGINT IDENTITY PRIMARY KEY,
    id_ejecucion UNIQUEIDENTIFIER NOT NULL,
    nombre_prueba VARCHAR(150) NOT NULL,
    capa VARCHAR(20) NOT NULL,
    resultado VARCHAR(10) NOT NULL,
    valor_observado INT NOT NULL,
    valor_esperado INT NOT NULL,
    detalle NVARCHAR(500),
    fecha_ejecucion DATETIME2(3) DEFAULT SYSDATETIME()
);
GO

DECLARE @id UNIQUEIDENTIFIER = NEWID();
DECLARE @d1 INT,@d2 INT,@h INT,@n INT,@f INT,@c INT;

SELECT @d1=COUNT(*) FROM (
    SELECT cliente_key FROM gold.dim_clientes GROUP BY cliente_key HAVING COUNT(*)>1
)x;

SELECT @d2=COUNT(*) FROM (
    SELECT transaccion_key FROM gold.fact_transacciones GROUP BY transaccion_key HAVING COUNT(*)>1
)x;

SELECT @h =
    ISNULL(SUM(CASE WHEN dc.cliente_key IS NULL THEN 1 ELSE 0 END),0)+
    ISNULL(SUM(CASE WHEN dp.producto_key IS NULL THEN 1 ELSE 0 END),0)+
    ISNULL(SUM(CASE WHEN ca.canal_key IS NULL THEN 1 ELSE 0 END),0)+
    ISNULL(SUM(CASE WHEN dg.geografia_key IS NULL THEN 1 ELSE 0 END),0)
FROM gold.fact_transacciones ft
LEFT JOIN gold.dim_clientes dc ON ft.cliente_key=dc.cliente_key
LEFT JOIN gold.dim_productos dp ON ft.producto_key=dp.producto_key
LEFT JOIN gold.dim_canal ca ON ft.canal_key=ca.canal_key
LEFT JOIN gold.dim_geografia dg ON ft.geografia_key=dg.geografia_key;

SELECT @n=COUNT(*)
FROM gold.fact_cartera
WHERE clasificacion_regulatoria IS NULL
   OR porcentaje_provision IS NULL
   OR provision_estimada IS NULL;

SELECT @f=ABS(
    (SELECT COUNT(*) FROM silver.movimientos WHERE ind_sospechoso=1)-
    (SELECT COUNT(*) FROM gold.fact_transacciones WHERE ind_sospechoso=1)
);

SELECT @c=COUNT(*)
FROM gold.fact_rentabilidad_cliente
WHERE ABS(cltv_mensual-(ISNULL(ingreso_intereses,0)+ISNULL(comisiones_cobradas,0)))>0.01;

INSERT INTO dbo.RESULTADO_PRUEBAS_CALIDAD
(id_ejecucion,nombre_prueba,capa,resultado,valor_observado,valor_esperado,detalle)
SELECT @id,'Duplicados en dim_clientes','GOLD',IIF(@d1=0,'PASS','FAIL'),@d1,0,'No deben existir duplicados.'
UNION ALL
SELECT @id,'Duplicados en fact_transacciones','GOLD',IIF(@d2=0,'PASS','FAIL'),@d2,0,'No deben existir duplicados.'
UNION ALL
SELECT @id,'Integridad referencial fact_transacciones','GOLD',IIF(@h=0,'PASS','FAIL'),@h,0,'No deben existir relaciones faltantes.'
UNION ALL
SELECT @id,'Nulos criticos fact_cartera','GOLD',IIF(@n=0,'PASS','FAIL'),@n,0,'No deben existir nulos criticos.'
UNION ALL
SELECT @id,'Consistencia fraude Silver vs Gold','SILVER-GOLD',IIF(@f=0,'PASS','FAIL'),@f,0,'Silver y Gold deben coincidir.'
UNION ALL
SELECT @id,'Consistencia calculo CLTV','GOLD',IIF(@c=0,'PASS','FAIL'),@c,0,'CLTV debe coincidir con intereses y comisiones.';
GO

SELECT nombre_prueba,capa,resultado,valor_observado,valor_esperado
FROM dbo.RESULTADO_PRUEBAS_CALIDAD
WHERE id_ejecucion=(SELECT MAX(id_ejecucion) FROM dbo.RESULTADO_PRUEBAS_CALIDAD);
GO

SELECT
    COUNT(*) total_pruebas,
    SUM(IIF(resultado='PASS',1,0)) pruebas_pass,
    SUM(IIF(resultado='FAIL',1,0)) pruebas_fail
FROM dbo.RESULTADO_PRUEBAS_CALIDAD
WHERE id_ejecucion=(SELECT MAX(id_ejecucion) FROM dbo.RESULTADO_PRUEBAS_CALIDAD);
GO

-- LOG DE ERRORES
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
GO

IF NOT EXISTS(
    SELECT 1 FROM dbo.PIPELINE_ERROR_LOG
    WHERE tipo_error='ERROR_PRUEBA_CONTROLADO'
)
INSERT INTO dbo.PIPELINE_ERROR_LOG
(id_ejecucion,etapa,proceso,tipo_error,mensaje_error,estado)
VALUES(
    NEWID(),
    'VALIDACION',
    'Prueba controlada de manejo de errores',
    'ERROR_PRUEBA_CONTROLADO',
    'Registro generado para validar el manejo de errores.',
    'CONTROLADO'
);
GO

SELECT TOP 1
    proceso,
    tipo_error,
    estado
FROM dbo.PIPELINE_ERROR_LOG
WHERE tipo_error='ERROR_PRUEBA_CONTROLADO'
ORDER BY id_error DESC;
GO
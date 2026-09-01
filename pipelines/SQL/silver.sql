USE FINBANK;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='silver')
    EXEC('CREATE SCHEMA silver');
GO

DROP TABLE IF EXISTS silver.registros_rechazados;
CREATE TABLE silver.registros_rechazados(
    id_rechazo BIGINT IDENTITY PRIMARY KEY,
    tabla_origen VARCHAR(100) NOT NULL,
    id_registro VARCHAR(100),
    tipo_error VARCHAR(100) NOT NULL,
    campo_error VARCHAR(100),
    motivo_rechazo VARCHAR(500) NOT NULL,
    fecha_rechazo DATETIME2(3) DEFAULT SYSDATETIME()
);
GO

/* CLIENTES */
INSERT INTO silver.registros_rechazados
(tabla_origen,id_registro,tipo_error,campo_error,motivo_rechazo)
SELECT
    'TB_CLIENTES_CORE',
    COALESCE(CAST(id_cli AS VARCHAR(100)),'NULL'),
    CASE WHEN fec_nac>CAST(GETDATE() AS DATE)
         THEN 'FECHA_INVALIDA' ELSE 'CAMPO_OBLIGATORIO_NULO' END,
    CASE
        WHEN id_cli IS NULL THEN 'id_cli'
        WHEN NULLIF(LTRIM(RTRIM(nomb_cli)),'') IS NULL THEN 'nomb_cli'
        WHEN NULLIF(LTRIM(RTRIM(apell_cli)),'') IS NULL THEN 'apell_cli'
        WHEN NULLIF(LTRIM(RTRIM(num_doc)),'') IS NULL THEN 'num_doc'
        WHEN fec_nac IS NULL OR fec_nac>CAST(GETDATE() AS DATE) THEN 'fec_nac'
    END,
    CASE
        WHEN id_cli IS NULL THEN 'El identificador del cliente es obligatorio.'
        WHEN NULLIF(LTRIM(RTRIM(nomb_cli)),'') IS NULL THEN 'El nombre es obligatorio.'
        WHEN NULLIF(LTRIM(RTRIM(apell_cli)),'') IS NULL THEN 'El apellido es obligatorio.'
        WHEN NULLIF(LTRIM(RTRIM(num_doc)),'') IS NULL THEN 'El documento es obligatorio.'
        WHEN fec_nac IS NULL THEN 'La fecha de nacimiento es obligatoria.'
        ELSE 'La fecha de nacimiento no puede ser futura.'
    END
FROM bronze.TB_CLIENTES_CORE
WHERE id_cli IS NULL
   OR NULLIF(LTRIM(RTRIM(nomb_cli)),'') IS NULL
   OR NULLIF(LTRIM(RTRIM(apell_cli)),'') IS NULL
   OR NULLIF(LTRIM(RTRIM(num_doc)),'') IS NULL
   OR fec_nac IS NULL
   OR fec_nac>CAST(GETDATE() AS DATE);
GO

DROP TABLE IF EXISTS silver.clientes;
WITH x AS(
    SELECT b.*,ROW_NUMBER() OVER(PARTITION BY id_cli ORDER BY fecha_ingesta DESC,id_lote DESC) rn
    FROM bronze.TB_CLIENTES_CORE b
    WHERE NOT EXISTS(
        SELECT 1 FROM silver.registros_rechazados r
        WHERE r.tabla_origen='TB_CLIENTES_CORE'
          AND r.id_registro=CAST(b.id_cli AS VARCHAR(100))
    )
)
SELECT
    id_cli,
    CONCAT(LEFT(LTRIM(RTRIM(nomb_cli)),1),'***') nomb_cli,
    CONCAT(LEFT(LTRIM(RTRIM(apell_cli)),1),'***') apell_cli,
    CONCAT(LEFT(LTRIM(RTRIM(nomb_cli)),1),'*** ',LEFT(LTRIM(RTRIM(apell_cli)),1),'***') nombre_completo,
    UPPER(LTRIM(RTRIM(tip_doc))) tip_doc,
    CASE WHEN LEN(num_doc)<=4 THEN '****'
         ELSE CONCAT(REPLICATE('*',LEN(num_doc)-4),RIGHT(num_doc,4)) END num_doc,
    CASE WHEN LEN(num_doc)<=4 THEN '****'
         ELSE CONCAT(REPLICATE('*',LEN(num_doc)-4),RIGHT(num_doc,4)) END num_doc_enmascarado,
    fec_nac,
    DATEDIFF(YEAR,fec_nac,GETDATE())-
    CASE WHEN DATEADD(YEAR,DATEDIFF(YEAR,fec_nac,GETDATE()),fec_nac)>CAST(GETDATE() AS DATE)
         THEN 1 ELSE 0 END edad,
    fec_alta,
    COALESCE(NULLIF(LTRIM(RTRIM(cod_segmento)),''),'NO_INFORMADO') cod_segmento,
    CASE
        WHEN UPPER(cod_segmento) IN('BASICO','BÁSICO') THEN 'Básico'
        WHEN UPPER(cod_segmento) IN('ESTANDAR','ESTÁNDAR') THEN 'Estándar'
        WHEN UPPER(cod_segmento)='PREMIUM' THEN 'Premium'
        WHEN UPPER(cod_segmento) IN('ELITE','ÉLITE') THEN 'Élite'
        ELSE COALESCE(cod_segmento,'NO_INFORMADO')
    END segmento_legible,
    COALESCE(score_buro,0) score_buro,
    COALESCE(ciudad_res,'NO_INFORMADO') ciudad_res,
    COALESCE(depto_res,'NO_INFORMADO') depto_res,
    COALESCE(estado_cli,'NO_INFORMADO') estado_cli,
    COALESCE(canal_adquis,'NO_INFORMADO') canal_adquis
INTO silver.clientes
FROM x WHERE rn=1;
GO

/* PRODUCTOS */
DROP TABLE IF EXISTS silver.productos;
WITH x AS(
    SELECT b.*,ROW_NUMBER() OVER(PARTITION BY cod_prod ORDER BY fecha_ingesta DESC,id_lote DESC) rn
    FROM bronze.TB_PRODUCTOS_CAT b
    WHERE cod_prod IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(desc_prod)),'') IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(tip_prod)),'') IS NOT NULL
)
SELECT
    cod_prod,
    LTRIM(RTRIM(desc_prod)) nombre_producto,
    UPPER(LTRIM(RTRIM(tip_prod))) tipo_producto,
    COALESCE(tasa_ea,0) tasa_ea,
    CAST((POWER(1+COALESCE(tasa_ea,0)/100.0,1.0/12.0)-1)*100 AS DECIMAL(10,4)) tasa_mensual_equivalente,
    COALESCE(plazo_max_meses,0) plazo_max_meses,
    COALESCE(cuota_min,0) cuota_min,
    COALESCE(comision_admin,0) comision_admin,
    COALESCE(estado_prod,'NO_INFORMADO') estado_prod,
    CASE
        WHEN UPPER(tip_prod) LIKE '%CREDITO%' OR UPPER(tip_prod) LIKE '%CRÉDITO%' OR UPPER(tip_prod) LIKE '%TARJETA%' THEN 'CREDITO'
        WHEN UPPER(tip_prod) LIKE '%AHORRO%' THEN 'AHORRO'
        ELSE 'TRANSACCIONAL'
    END familia_producto
INTO silver.productos
FROM x WHERE rn=1;
GO

/* SUCURSALES */
DROP TABLE IF EXISTS silver.sucursales;
WITH x AS(
    SELECT b.*,ROW_NUMBER() OVER(PARTITION BY cod_suc ORDER BY fecha_ingesta DESC,id_lote DESC) rn
    FROM bronze.TB_SUCURSALES_RED b
    WHERE cod_suc IS NOT NULL
      AND NULLIF(LTRIM(RTRIM(nom_suc)),'') IS NOT NULL
)
SELECT
    cod_suc,
    LTRIM(RTRIM(nom_suc)) nombre_sucursal,
    COALESCE(tip_punto,'NO_INFORMADO') tipo_punto,
    COALESCE(ciudad,'NO_INFORMADO') ciudad,
    COALESCE(depto,'NO_INFORMADO') departamento,
    latitud,longitud,
    COALESCE(activo,0) activo,
    CASE WHEN COALESCE(activo,0)=1 THEN 'ACTIVA' ELSE 'INACTIVA' END estado_sucursal
INTO silver.sucursales
FROM x WHERE rn=1;
GO

/* OBLIGACIONES RECHAZADAS */
INSERT INTO silver.registros_rechazados
(tabla_origen,id_registro,tipo_error,campo_error,motivo_rechazo)
SELECT
    'TB_OBLIGACIONES',
    COALESCE(CAST(o.id_oblig AS VARCHAR(100)),'NULL'),
    CASE
        WHEN o.id_oblig IS NULL OR o.id_cli IS NULL OR o.cod_prod IS NULL
          OR o.fec_desembolso IS NULL OR o.fec_venc IS NULL THEN 'CAMPO_OBLIGATORIO_NULO'
        WHEN c.id_cli IS NULL THEN 'CLIENTE_INEXISTENTE'
        WHEN p.cod_prod IS NULL THEN 'PRODUCTO_INEXISTENTE'
        ELSE 'FECHA_VENCIMIENTO_INVALIDA'
    END,
    CASE
        WHEN o.id_oblig IS NULL THEN 'id_oblig'
        WHEN o.id_cli IS NULL THEN 'id_cli'
        WHEN o.cod_prod IS NULL THEN 'cod_prod'
        WHEN o.fec_desembolso IS NULL THEN 'fec_desembolso'
        WHEN o.fec_venc IS NULL THEN 'fec_venc'
        WHEN c.id_cli IS NULL THEN 'id_cli'
        WHEN p.cod_prod IS NULL THEN 'cod_prod'
        ELSE 'fec_venc'
    END,
    CASE
        WHEN o.id_oblig IS NULL THEN 'El identificador es obligatorio.'
        WHEN o.id_cli IS NULL THEN 'El cliente es obligatorio.'
        WHEN o.cod_prod IS NULL THEN 'El producto es obligatorio.'
        WHEN o.fec_desembolso IS NULL THEN 'La fecha de desembolso es obligatoria.'
        WHEN o.fec_venc IS NULL THEN 'La fecha de vencimiento es obligatoria.'
        WHEN c.id_cli IS NULL THEN 'El cliente no existe en Silver.'
        WHEN p.cod_prod IS NULL THEN 'El producto no existe en Silver.'
        ELSE 'La fecha de vencimiento es anterior a la fecha de desembolso.'
    END
FROM bronze.TB_OBLIGACIONES o
LEFT JOIN silver.clientes c ON c.id_cli=o.id_cli
LEFT JOIN silver.productos p ON p.cod_prod=o.cod_prod
WHERE o.id_oblig IS NULL
   OR o.id_cli IS NULL
   OR o.cod_prod IS NULL
   OR o.fec_desembolso IS NULL
   OR o.fec_venc IS NULL
   OR c.id_cli IS NULL
   OR p.cod_prod IS NULL
   OR o.fec_venc<o.fec_desembolso;
GO

DROP TABLE IF EXISTS silver.obligaciones;
WITH x AS(
    SELECT b.*,ROW_NUMBER() OVER(PARTITION BY id_oblig ORDER BY fecha_ingesta DESC,id_lote DESC) rn
    FROM bronze.TB_OBLIGACIONES b
    WHERE NOT EXISTS(
        SELECT 1 FROM silver.registros_rechazados r
        WHERE r.tabla_origen='TB_OBLIGACIONES'
          AND r.id_registro=CAST(b.id_oblig AS VARCHAR(100))
    )
)
SELECT
    id_oblig,id_cli,cod_prod,
    COALESCE(vr_aprobado,0) vr_aprobado,
    COALESCE(vr_desembolsado,0) vr_desembolsado,
    COALESCE(sdo_capital,0) sdo_capital,
    COALESCE(vr_cuota,0) vr_cuota,
    fec_desembolso,fec_venc,
    COALESCE(dias_mora_act,0) dias_mora_act,
    COALESCE(num_cuotas_pend,0) num_cuotas_pend,
    COALESCE(calif_riesgo,'NO_INFORMADO') calif_riesgo,
    CASE
        WHEN COALESCE(dias_mora_act,0)=0 THEN 'AL DIA'
        WHEN dias_mora_act BETWEEN 1 AND 30 THEN 'RANGO 1'
        WHEN dias_mora_act BETWEEN 31 AND 60 THEN 'RANGO 2'
        WHEN dias_mora_act BETWEEN 61 AND 90 THEN 'RANGO 3'
        ELSE 'DETERIORADO'
    END bucket_mora,
    0 ind_fecha_inconsistente,
    'VALIDO' estado_calidad
INTO silver.obligaciones
FROM x WHERE rn=1;
GO

/* COMISIONES */
DROP TABLE IF EXISTS silver.comisiones;
WITH x AS(
    SELECT b.*,ROW_NUMBER() OVER(PARTITION BY id_comision ORDER BY fecha_ingesta DESC,id_lote DESC) rn
    FROM bronze.TB_COMISIONES_LOG b
    WHERE id_comision IS NOT NULL
      AND id_cli IS NOT NULL
      AND cod_prod IS NOT NULL
      AND fec_cobro IS NOT NULL
      AND vr_comision IS NOT NULL
      AND vr_comision>=0
      AND EXISTS(SELECT 1 FROM silver.clientes c WHERE c.id_cli=b.id_cli)
      AND EXISTS(SELECT 1 FROM silver.productos p WHERE p.cod_prod=b.cod_prod)
)
SELECT
    id_comision,id_cli,cod_prod,fec_cobro,vr_comision,
    COALESCE(tip_comision,'NO_INFORMADO') tip_comision,
    COALESCE(estado_cobro,'NO_INFORMADO') estado_cobro,
    CASE WHEN UPPER(estado_cobro)='COBRADA' THEN 1 ELSE 0 END ind_comision_cobrada,
    0 ind_valor_inconsistente
INTO silver.comisiones
FROM x WHERE rn=1;
GO

/* INCENTIVOS */
DROP TABLE IF EXISTS silver.incentivos;
WITH x AS(
    SELECT b.*,ROW_NUMBER() OVER(PARTITION BY id_incentivo ORDER BY fecha_ingesta DESC,id_lote DESC) rn
    FROM bronze.TB_INCENTIVOS b
    WHERE id_incentivo IS NOT NULL
      AND id_cli IS NOT NULL
      AND cod_prod IS NOT NULL
      AND fec_incentivo IS NOT NULL
      AND vr_incentivo IS NOT NULL
      AND vr_incentivo>=0
      AND EXISTS(SELECT 1 FROM silver.clientes c WHERE c.id_cli=b.id_cli)
      AND EXISTS(SELECT 1 FROM silver.productos p WHERE p.cod_prod=b.cod_prod)
)
SELECT
    id_incentivo,id_cli,cod_prod,fec_incentivo,
    COALESCE(tip_incentivo,'NO_INFORMADO') tip_incentivo,
    vr_incentivo,
    COALESCE(estado_incentivo,'NO_INFORMADO') estado_incentivo,
    CASE WHEN UPPER(estado_incentivo)='OTORGADO' THEN 1 ELSE 0 END ind_incentivo_otorgado,
    0 ind_valor_inconsistente
INTO silver.incentivos
FROM x WHERE rn=1;
GO

/* MOVIMIENTOS + FRAUDE */
DROP TABLE IF EXISTS silver.movimientos;
WITH x AS(
    SELECT b.*,ROW_NUMBER() OVER(PARTITION BY id_mov ORDER BY fecha_ingesta DESC,id_lote DESC) rn
    FROM bronze.TB_MOV_FINANCIEROS b
    WHERE id_mov IS NOT NULL
      AND id_cli IS NOT NULL
      AND cod_prod IS NOT NULL
      AND fec_mov IS NOT NULL
      AND hra_mov IS NOT NULL
      AND vr_mov IS NOT NULL
      AND EXISTS(SELECT 1 FROM silver.clientes c WHERE c.id_cli=b.id_cli)
      AND EXISTS(SELECT 1 FROM silver.productos p WHERE p.cod_prod=b.cod_prod)
),
m AS(
    SELECT x.*,
        (SELECT COUNT(*) FROM x h
         WHERE h.id_cli=x.id_cli
           AND h.fec_mov>=DATEADD(DAY,-30,x.fec_mov)
           AND (h.fec_mov<x.fec_mov OR
               (h.fec_mov=x.fec_mov AND h.hra_mov<x.hra_mov) OR
               (h.fec_mov=x.fec_mov AND h.hra_mov=x.hra_mov AND h.id_mov<x.id_mov))) movimientos_previos,
        (SELECT AVG(CAST(h.vr_mov AS DECIMAL(18,2))) FROM x h
         WHERE h.id_cli=x.id_cli
           AND h.fec_mov>=DATEADD(DAY,-30,x.fec_mov)
           AND (h.fec_mov<x.fec_mov OR
               (h.fec_mov=x.fec_mov AND h.hra_mov<x.hra_mov) OR
               (h.fec_mov=x.fec_mov AND h.hra_mov=x.hra_mov AND h.id_mov<x.id_mov))) promedio_historico,
        (SELECT STDEV(CAST(h.vr_mov AS FLOAT)) FROM x h
         WHERE h.id_cli=x.id_cli
           AND h.fec_mov>=DATEADD(DAY,-30,x.fec_mov)
           AND (h.fec_mov<x.fec_mov OR
               (h.fec_mov=x.fec_mov AND h.hra_mov<x.hra_mov) OR
               (h.fec_mov=x.fec_mov AND h.hra_mov=x.hra_mov AND h.id_mov<x.id_mov))) desviacion_historica,
        (SELECT COUNT(*) FROM x d WHERE d.id_cli=x.id_cli AND d.fec_mov=x.fec_mov) frecuencia_diaria
    FROM x WHERE rn=1
),
r AS(
    SELECT *,
        CASE WHEN movimientos_previos>=3 AND desviacion_historica IS NOT NULL
                  AND vr_mov>promedio_historico+3*desviacion_historica THEN 1 ELSE 0 END alerta_monto,
        CASE WHEN hra_mov>=CAST('00:00:00' AS TIME) AND hra_mov<CAST('05:00:00' AS TIME) THEN 1 ELSE 0 END alerta_horario,
        CASE WHEN frecuencia_diaria>=5 THEN 1 ELSE 0 END alerta_frecuencia,
        CASE WHEN UPPER(cod_canal) IN('ATM','CORRESPONSAL') THEN 1 ELSE 0 END alerta_canal
    FROM m
)
SELECT
    id_mov,id_cli,cod_prod,num_cuenta,fec_mov,hra_mov,vr_mov,
    COALESCE(tip_mov,'NO_INFORMADO') tip_mov,
    COALESCE(cod_canal,'NO_INFORMADO') cod_canal,
    COALESCE(cod_ciudad,'NO_INFORMADO') cod_ciudad,
    COALESCE(cod_estado_mov,'NO_INFORMADO') cod_estado_mov,
    COALESCE(id_dispositivo,'NO_INFORMADO') id_dispositivo,
    fecha_ingesta,sistema_fuente,id_lote,
    movimientos_previos,promedio_historico,desviacion_historica,frecuencia_diaria,
    alerta_monto,alerta_horario,alerta_frecuencia,alerta_canal,
    alerta_monto+alerta_horario+alerta_frecuencia+alerta_canal total_alertas,
    CASE WHEN alerta_monto=1 THEN 1 ELSE 0 END ind_sospechoso
INTO silver.movimientos
FROM r;
GO

/* OBLIGACIONES RECHAZADAS */
DROP TABLE IF EXISTS silver.obligaciones_rechazadas;
SELECT
    o.id_oblig,o.id_cli,o.cod_prod,o.fec_desembolso,o.fec_venc,
    o.dias_mora_act,o.calif_riesgo,
    r.tipo_error,r.motivo_rechazo,r.fecha_rechazo
INTO silver.obligaciones_rechazadas
FROM bronze.TB_OBLIGACIONES o
JOIN silver.registros_rechazados r
  ON r.tabla_origen='TB_OBLIGACIONES'
 AND r.id_registro=CAST(o.id_oblig AS VARCHAR(100));
GO

/* CALIDAD */
DROP TABLE IF EXISTS silver.reporte_calidad;
CREATE TABLE silver.reporte_calidad(
    tabla VARCHAR(100),
    registros_bronze INT,
    registros_silver INT,
    registros_rechazados INT,
    porcentaje_conformidad DECIMAL(10,2),
    fecha_ejecucion DATETIME2(3)
);
GO

INSERT INTO silver.reporte_calidad
SELECT 'clientes',COUNT(*),(SELECT COUNT(*) FROM silver.clientes),
       (SELECT COUNT(*) FROM silver.registros_rechazados WHERE tabla_origen='TB_CLIENTES_CORE'),
       CAST(100.0*(SELECT COUNT(*) FROM silver.clientes)/NULLIF(COUNT(*),0) AS DECIMAL(10,2)),SYSDATETIME()
FROM bronze.TB_CLIENTES_CORE
UNION ALL
SELECT 'productos',COUNT(*),(SELECT COUNT(*) FROM silver.productos),0,
       CAST(100.0*(SELECT COUNT(*) FROM silver.productos)/NULLIF(COUNT(*),0) AS DECIMAL(10,2)),SYSDATETIME()
FROM bronze.TB_PRODUCTOS_CAT
UNION ALL
SELECT 'sucursales',COUNT(*),(SELECT COUNT(*) FROM silver.sucursales),0,
       CAST(100.0*(SELECT COUNT(*) FROM silver.sucursales)/NULLIF(COUNT(*),0) AS DECIMAL(10,2)),SYSDATETIME()
FROM bronze.TB_SUCURSALES_RED
UNION ALL
SELECT 'obligaciones',COUNT(*),(SELECT COUNT(*) FROM silver.obligaciones),
       (SELECT COUNT(*) FROM silver.registros_rechazados WHERE tabla_origen='TB_OBLIGACIONES'),
       CAST(100.0*(SELECT COUNT(*) FROM silver.obligaciones)/NULLIF(COUNT(*),0) AS DECIMAL(10,2)),SYSDATETIME()
FROM bronze.TB_OBLIGACIONES
UNION ALL
SELECT 'movimientos',COUNT(*),(SELECT COUNT(*) FROM silver.movimientos),0,
       CAST(100.0*(SELECT COUNT(*) FROM silver.movimientos)/NULLIF(COUNT(*),0) AS DECIMAL(10,2)),SYSDATETIME()
FROM bronze.TB_MOV_FINANCIEROS
UNION ALL
SELECT 'comisiones',COUNT(*),(SELECT COUNT(*) FROM silver.comisiones),0,
       CAST(100.0*(SELECT COUNT(*) FROM silver.comisiones)/NULLIF(COUNT(*),0) AS DECIMAL(10,2)),SYSDATETIME()
FROM bronze.TB_COMISIONES_LOG
UNION ALL
SELECT 'incentivos',COUNT(*),(SELECT COUNT(*) FROM silver.incentivos),0,
       CAST(100.0*(SELECT COUNT(*) FROM silver.incentivos)/NULLIF(COUNT(*),0) AS DECIMAL(10,2)),SYSDATETIME()
FROM bronze.TB_INCENTIVOS;
GO

/* NULOS POR COLUMNA */
DROP TABLE IF EXISTS silver.calidad_nulos;
CREATE TABLE silver.calidad_nulos(
    tabla VARCHAR(100),
    columna VARCHAR(100),
    total_registros INT,
    registros_nulos INT,
    porcentaje_nulos DECIMAL(10,2),
    fecha_ejecucion DATETIME2(3)
);
GO

DECLARE @t SYSNAME,@c SYSNAME,@s NVARCHAR(MAX);

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
SELECT t.name,c.name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id=t.schema_id
JOIN sys.columns c ON c.object_id=t.object_id
WHERE s.name='silver'
  AND t.name IN('clientes','productos','sucursales','obligaciones','movimientos','comisiones','incentivos');

OPEN cur;
FETCH NEXT FROM cur INTO @t,@c;

WHILE @@FETCH_STATUS=0
BEGIN
    SET @s=N'
    INSERT INTO silver.calidad_nulos
    SELECT '''+@t+''','''+@c+''',COUNT(*),
           SUM(CASE WHEN '+QUOTENAME(@c)+' IS NULL THEN 1 ELSE 0 END),
           CAST(100.0*SUM(CASE WHEN '+QUOTENAME(@c)+' IS NULL THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS DECIMAL(10,2)),
           SYSDATETIME()
    FROM silver.'+QUOTENAME(@t)+';';
    EXEC sys.sp_executesql @s;
    FETCH NEXT FROM cur INTO @t,@c;
END;

CLOSE cur;
DEALLOCATE cur;
GO

PRINT 'CAPA SILVER FINALIZADA CORRECTAMENTE';
GO
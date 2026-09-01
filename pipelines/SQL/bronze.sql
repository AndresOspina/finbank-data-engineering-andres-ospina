-- FINBANK - BRONZE
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- Columnas de auditoria
IF COL_LENGTH('bronze.TB_CLIENTES_CORE','fecha_ingesta') IS NULL
    ALTER TABLE bronze.TB_CLIENTES_CORE ADD fecha_ingesta DATETIME2 NULL;
IF COL_LENGTH('bronze.TB_CLIENTES_CORE','sistema_fuente') IS NULL
    ALTER TABLE bronze.TB_CLIENTES_CORE ADD sistema_fuente VARCHAR(50) NULL;
IF COL_LENGTH('bronze.TB_CLIENTES_CORE','id_lote') IS NULL
    ALTER TABLE bronze.TB_CLIENTES_CORE ADD id_lote UNIQUEIDENTIFIER NULL;

IF COL_LENGTH('bronze.TB_PRODUCTOS_CAT','fecha_ingesta') IS NULL
    ALTER TABLE bronze.TB_PRODUCTOS_CAT ADD fecha_ingesta DATETIME2 NULL;
IF COL_LENGTH('bronze.TB_PRODUCTOS_CAT','sistema_fuente') IS NULL
    ALTER TABLE bronze.TB_PRODUCTOS_CAT ADD sistema_fuente VARCHAR(50) NULL;
IF COL_LENGTH('bronze.TB_PRODUCTOS_CAT','id_lote') IS NULL
    ALTER TABLE bronze.TB_PRODUCTOS_CAT ADD id_lote UNIQUEIDENTIFIER NULL;

IF COL_LENGTH('bronze.TB_SUCURSALES_RED','fecha_ingesta') IS NULL
    ALTER TABLE bronze.TB_SUCURSALES_RED ADD fecha_ingesta DATETIME2 NULL;
IF COL_LENGTH('bronze.TB_SUCURSALES_RED','sistema_fuente') IS NULL
    ALTER TABLE bronze.TB_SUCURSALES_RED ADD sistema_fuente VARCHAR(50) NULL;
IF COL_LENGTH('bronze.TB_SUCURSALES_RED','id_lote') IS NULL
    ALTER TABLE bronze.TB_SUCURSALES_RED ADD id_lote UNIQUEIDENTIFIER NULL;

IF COL_LENGTH('bronze.TB_OBLIGACIONES','fecha_ingesta') IS NULL
    ALTER TABLE bronze.TB_OBLIGACIONES ADD fecha_ingesta DATETIME2 NULL;
IF COL_LENGTH('bronze.TB_OBLIGACIONES','sistema_fuente') IS NULL
    ALTER TABLE bronze.TB_OBLIGACIONES ADD sistema_fuente VARCHAR(50) NULL;
IF COL_LENGTH('bronze.TB_OBLIGACIONES','id_lote') IS NULL
    ALTER TABLE bronze.TB_OBLIGACIONES ADD id_lote UNIQUEIDENTIFIER NULL;

IF COL_LENGTH('bronze.TB_MOV_FINANCIEROS','fecha_ingesta') IS NULL
    ALTER TABLE bronze.TB_MOV_FINANCIEROS ADD fecha_ingesta DATETIME2 NULL;
IF COL_LENGTH('bronze.TB_MOV_FINANCIEROS','sistema_fuente') IS NULL
    ALTER TABLE bronze.TB_MOV_FINANCIEROS ADD sistema_fuente VARCHAR(50) NULL;
IF COL_LENGTH('bronze.TB_MOV_FINANCIEROS','id_lote') IS NULL
    ALTER TABLE bronze.TB_MOV_FINANCIEROS ADD id_lote UNIQUEIDENTIFIER NULL;

IF COL_LENGTH('bronze.TB_COMISIONES_LOG','fecha_ingesta') IS NULL
    ALTER TABLE bronze.TB_COMISIONES_LOG ADD fecha_ingesta DATETIME2 NULL;
IF COL_LENGTH('bronze.TB_COMISIONES_LOG','sistema_fuente') IS NULL
    ALTER TABLE bronze.TB_COMISIONES_LOG ADD sistema_fuente VARCHAR(50) NULL;
IF COL_LENGTH('bronze.TB_COMISIONES_LOG','id_lote') IS NULL
    ALTER TABLE bronze.TB_COMISIONES_LOG ADD id_lote UNIQUEIDENTIFIER NULL;

IF COL_LENGTH('bronze.TB_INCENTIVOS','fecha_ingesta') IS NULL
    ALTER TABLE bronze.TB_INCENTIVOS ADD fecha_ingesta DATETIME2 NULL;
IF COL_LENGTH('bronze.TB_INCENTIVOS','sistema_fuente') IS NULL
    ALTER TABLE bronze.TB_INCENTIVOS ADD sistema_fuente VARCHAR(50) NULL;
IF COL_LENGTH('bronze.TB_INCENTIVOS','id_lote') IS NULL
    ALTER TABLE bronze.TB_INCENTIVOS ADD id_lote UNIQUEIDENTIFIER NULL;
GO

DECLARE @fecha DATETIME2 = SYSDATETIME();
DECLARE @lote UNIQUEIDENTIFIER = NEWID();
DECLARE @fuente VARCHAR(50) = 'SQLSERVER_FINBANK';

-- CLIENTES
MERGE bronze.TB_CLIENTES_CORE d
USING dbo.TB_CLIENTES_CORE s
ON d.id_cli = s.id_cli
WHEN MATCHED AND EXISTS (
    SELECT s.nomb_cli,s.apell_cli,s.tip_doc,s.num_doc,s.fec_nac,s.fec_alta,
           s.cod_segmento,s.score_buro,s.ciudad_res,s.depto_res,s.estado_cli,s.canal_adquis
    EXCEPT
    SELECT d.nomb_cli,d.apell_cli,d.tip_doc,d.num_doc,d.fec_nac,d.fec_alta,
           d.cod_segmento,d.score_buro,d.ciudad_res,d.depto_res,d.estado_cli,d.canal_adquis
)
THEN UPDATE SET
    nomb_cli=s.nomb_cli, apell_cli=s.apell_cli, tip_doc=s.tip_doc,
    num_doc=s.num_doc, fec_nac=s.fec_nac, fec_alta=s.fec_alta,
    cod_segmento=s.cod_segmento, score_buro=s.score_buro,
    ciudad_res=s.ciudad_res, depto_res=s.depto_res,
    estado_cli=s.estado_cli, canal_adquis=s.canal_adquis,
    fecha_ingesta=@fecha, sistema_fuente=@fuente, id_lote=@lote
WHEN NOT MATCHED THEN
INSERT (
    id_cli,nomb_cli,apell_cli,tip_doc,num_doc,fec_nac,fec_alta,
    cod_segmento,score_buro,ciudad_res,depto_res,estado_cli,canal_adquis,
    fecha_ingesta,sistema_fuente,id_lote
)
VALUES (
    s.id_cli,s.nomb_cli,s.apell_cli,s.tip_doc,s.num_doc,s.fec_nac,s.fec_alta,
    s.cod_segmento,s.score_buro,s.ciudad_res,s.depto_res,s.estado_cli,s.canal_adquis,
    @fecha,@fuente,@lote
);

-- PRODUCTOS
MERGE bronze.TB_PRODUCTOS_CAT d
USING dbo.TB_PRODUCTOS_CAT s
ON d.cod_prod = s.cod_prod
WHEN MATCHED AND EXISTS (
    SELECT s.desc_prod,s.tip_prod,s.tasa_ea,s.plazo_max_meses,
           s.cuota_min,s.comision_admin,s.estado_prod
    EXCEPT
    SELECT d.desc_prod,d.tip_prod,d.tasa_ea,d.plazo_max_meses,
           d.cuota_min,d.comision_admin,d.estado_prod
)
THEN UPDATE SET
    desc_prod=s.desc_prod, tip_prod=s.tip_prod, tasa_ea=s.tasa_ea,
    plazo_max_meses=s.plazo_max_meses, cuota_min=s.cuota_min,
    comision_admin=s.comision_admin, estado_prod=s.estado_prod,
    fecha_ingesta=@fecha, sistema_fuente=@fuente, id_lote=@lote
WHEN NOT MATCHED THEN
INSERT (
    cod_prod,desc_prod,tip_prod,tasa_ea,plazo_max_meses,
    cuota_min,comision_admin,estado_prod,
    fecha_ingesta,sistema_fuente,id_lote
)
VALUES (
    s.cod_prod,s.desc_prod,s.tip_prod,s.tasa_ea,s.plazo_max_meses,
    s.cuota_min,s.comision_admin,s.estado_prod,
    @fecha,@fuente,@lote
);

-- SUCURSALES
MERGE bronze.TB_SUCURSALES_RED d
USING dbo.TB_SUCURSALES_RED s
ON d.cod_suc = s.cod_suc
WHEN MATCHED AND EXISTS (
    SELECT s.nom_suc,s.tip_punto,s.ciudad,s.depto,s.latitud,s.longitud,s.activo
    EXCEPT
    SELECT d.nom_suc,d.tip_punto,d.ciudad,d.depto,d.latitud,d.longitud,d.activo
)
THEN UPDATE SET
    nom_suc=s.nom_suc, tip_punto=s.tip_punto,
    ciudad=s.ciudad, depto=s.depto,
    latitud=s.latitud, longitud=s.longitud, activo=s.activo,
    fecha_ingesta=@fecha, sistema_fuente=@fuente, id_lote=@lote
WHEN NOT MATCHED THEN
INSERT (
    cod_suc,nom_suc,tip_punto,ciudad,depto,latitud,longitud,activo,
    fecha_ingesta,sistema_fuente,id_lote
)
VALUES (
    s.cod_suc,s.nom_suc,s.tip_punto,s.ciudad,s.depto,s.latitud,s.longitud,s.activo,
    @fecha,@fuente,@lote
);

-- OBLIGACIONES
MERGE bronze.TB_OBLIGACIONES d
USING dbo.TB_OBLIGACIONES s
ON d.id_oblig = s.id_oblig
WHEN MATCHED AND EXISTS (
    SELECT s.id_cli,s.cod_prod,s.vr_aprobado,s.vr_desembolsado,
           s.sdo_capital,s.vr_cuota,s.fec_desembolso,s.fec_venc,
           s.dias_mora_act,s.num_cuotas_pend,s.calif_riesgo
    EXCEPT
    SELECT d.id_cli,d.cod_prod,d.vr_aprobado,d.vr_desembolsado,
           d.sdo_capital,d.vr_cuota,d.fec_desembolso,d.fec_venc,
           d.dias_mora_act,d.num_cuotas_pend,d.calif_riesgo
)
THEN UPDATE SET
    id_cli=s.id_cli, cod_prod=s.cod_prod,
    vr_aprobado=s.vr_aprobado, vr_desembolsado=s.vr_desembolsado,
    sdo_capital=s.sdo_capital, vr_cuota=s.vr_cuota,
    fec_desembolso=s.fec_desembolso, fec_venc=s.fec_venc,
    dias_mora_act=s.dias_mora_act, num_cuotas_pend=s.num_cuotas_pend,
    calif_riesgo=s.calif_riesgo,
    fecha_ingesta=@fecha, sistema_fuente=@fuente, id_lote=@lote
WHEN NOT MATCHED THEN
INSERT (
    id_oblig,id_cli,cod_prod,vr_aprobado,vr_desembolsado,
    sdo_capital,vr_cuota,fec_desembolso,fec_venc,
    dias_mora_act,num_cuotas_pend,calif_riesgo,
    fecha_ingesta,sistema_fuente,id_lote
)
VALUES (
    s.id_oblig,s.id_cli,s.cod_prod,s.vr_aprobado,s.vr_desembolsado,
    s.sdo_capital,s.vr_cuota,s.fec_desembolso,s.fec_venc,
    s.dias_mora_act,s.num_cuotas_pend,s.calif_riesgo,
    @fecha,@fuente,@lote
);

-- MOVIMIENTOS
MERGE bronze.TB_MOV_FINANCIEROS d
USING dbo.TB_MOV_FINANCIEROS s
ON d.id_mov = s.id_mov
WHEN MATCHED AND EXISTS (
    SELECT s.id_cli,s.cod_prod,s.num_cuenta,s.fec_mov,s.hra_mov,
           s.vr_mov,s.tip_mov,s.cod_canal,s.cod_ciudad,
           s.cod_estado_mov,s.id_dispositivo
    EXCEPT
    SELECT d.id_cli,d.cod_prod,d.num_cuenta,d.fec_mov,d.hra_mov,
           d.vr_mov,d.tip_mov,d.cod_canal,d.cod_ciudad,
           d.cod_estado_mov,d.id_dispositivo
)
THEN UPDATE SET
    id_cli=s.id_cli, cod_prod=s.cod_prod, num_cuenta=s.num_cuenta,
    fec_mov=s.fec_mov, hra_mov=s.hra_mov, vr_mov=s.vr_mov,
    tip_mov=s.tip_mov, cod_canal=s.cod_canal, cod_ciudad=s.cod_ciudad,
    cod_estado_mov=s.cod_estado_mov, id_dispositivo=s.id_dispositivo,
    fecha_ingesta=@fecha, sistema_fuente=@fuente, id_lote=@lote
WHEN NOT MATCHED THEN
INSERT (
    id_mov,id_cli,cod_prod,num_cuenta,fec_mov,hra_mov,vr_mov,
    tip_mov,cod_canal,cod_ciudad,cod_estado_mov,id_dispositivo,
    fecha_ingesta,sistema_fuente,id_lote
)
VALUES (
    s.id_mov,s.id_cli,s.cod_prod,s.num_cuenta,s.fec_mov,s.hra_mov,s.vr_mov,
    s.tip_mov,s.cod_canal,s.cod_ciudad,s.cod_estado_mov,s.id_dispositivo,
    @fecha,@fuente,@lote
);

-- COMISIONES
MERGE bronze.TB_COMISIONES_LOG d
USING dbo.TB_COMISIONES_LOG s
ON d.id_comision = s.id_comision
WHEN MATCHED AND EXISTS (
    SELECT s.id_cli,s.cod_prod,s.fec_cobro,s.vr_comision,s.tip_comision,s.estado_cobro
    EXCEPT
    SELECT d.id_cli,d.cod_prod,d.fec_cobro,d.vr_comision,d.tip_comision,d.estado_cobro
)
THEN UPDATE SET
    id_cli=s.id_cli, cod_prod=s.cod_prod,
    fec_cobro=s.fec_cobro, vr_comision=s.vr_comision,
    tip_comision=s.tip_comision, estado_cobro=s.estado_cobro,
    fecha_ingesta=@fecha, sistema_fuente=@fuente, id_lote=@lote
WHEN NOT MATCHED THEN
INSERT (
    id_comision,id_cli,cod_prod,fec_cobro,vr_comision,
    tip_comision,estado_cobro,
    fecha_ingesta,sistema_fuente,id_lote
)
VALUES (
    s.id_comision,s.id_cli,s.cod_prod,s.fec_cobro,s.vr_comision,
    s.tip_comision,s.estado_cobro,
    @fecha,@fuente,@lote
);

-- INCENTIVOS
MERGE bronze.TB_INCENTIVOS d
USING dbo.TB_INCENTIVOS s
ON d.id_incentivo = s.id_incentivo
WHEN MATCHED AND EXISTS (
    SELECT s.id_cli,s.cod_prod,s.fec_incentivo,
           s.tip_incentivo,s.vr_incentivo,s.estado_incentivo
    EXCEPT
    SELECT d.id_cli,d.cod_prod,d.fec_incentivo,
           d.tip_incentivo,d.vr_incentivo,d.estado_incentivo
)
THEN UPDATE SET
    id_cli=s.id_cli, cod_prod=s.cod_prod,
    fec_incentivo=s.fec_incentivo,
    tip_incentivo=s.tip_incentivo,
    vr_incentivo=s.vr_incentivo,
    estado_incentivo=s.estado_incentivo,
    fecha_ingesta=@fecha, sistema_fuente=@fuente, id_lote=@lote
WHEN NOT MATCHED THEN
INSERT (
    id_incentivo,id_cli,cod_prod,fec_incentivo,
    tip_incentivo,vr_incentivo,estado_incentivo,
    fecha_ingesta,sistema_fuente,id_lote
)
VALUES (
    s.id_incentivo,s.id_cli,s.cod_prod,s.fec_incentivo,
    s.tip_incentivo,s.vr_incentivo,s.estado_incentivo,
    @fecha,@fuente,@lote
);

GO
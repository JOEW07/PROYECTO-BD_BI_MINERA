IF DB_ID('GLORE_PERU_DW') IS NULL CREATE DATABASE GLORE_PERU_DW;
GO
USE GLORE_PERU_DW;
GO

DROP TABLE IF EXISTS dbo.FactVentas, dbo.FactProduccion, dbo.FactGastos,
    dbo.DimCliente, dbo.DimYacimiento, dbo.DimTipoMineral, dbo.DimTipoGasto, dbo.DimTiempo;
GO

CREATE TABLE dbo.DimTiempo (
    IdTiempo    INT PRIMARY KEY,               
    Fecha       DATE NOT NULL,
    Anio        INT NOT NULL,
    Trimestre   INT NOT NULL,
    Mes         INT NOT NULL,
    NombreMes   VARCHAR(20) NOT NULL,
    Dia         INT NOT NULL,
    DiaSemana   VARCHAR(20) NOT NULL
);
GO

CREATE TABLE dbo.DimYacimiento (
    YacimientoKey INT IDENTITY(1,1) PRIMARY KEY,  
    IdYacimiento  INT NOT NULL,                  
    Nombre        VARCHAR(100) NOT NULL,
    Ubicacion     VARCHAR(150) NOT NULL,
    Estado        VARCHAR(20)  NOT NULL,
    FechaInicio   DATE NOT NULL,
    FechaFin      DATE NULL,
    EsActual      BIT  NOT NULL DEFAULT 1
);
GO

CREATE TABLE dbo.DimCliente (
    ClienteKey  INT IDENTITY(1,1) PRIMARY KEY,
    IdCliente   INT NOT NULL,
    RazonSocial VARCHAR(150) NOT NULL,
    Pais        VARCHAR(50)  NOT NULL,
    Continente  VARCHAR(50)  NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaFin    DATE NULL,
    EsActual    BIT  NOT NULL DEFAULT 1
);
GO

CREATE TABLE dbo.DimTipoMineral (
    MineralKey    INT IDENTITY(1,1) PRIMARY KEY,
    IdTipoMineral INT NOT NULL UNIQUE,
    Nombre        VARCHAR(50) NOT NULL,
    UnidadMedida  VARCHAR(20) NOT NULL
);
GO

CREATE TABLE dbo.DimTipoGasto (
    TipoGastoKey INT IDENTITY(1,1) PRIMARY KEY,
    IdTipoGasto  INT NOT NULL UNIQUE,
    Nombre       VARCHAR(50) NOT NULL
);
GO


CREATE TABLE dbo.FactProduccion (
    IdExtraccion       INT PRIMARY KEY,            -- dimension degenerada
    IdTiempo           INT NOT NULL REFERENCES dbo.DimTiempo(IdTiempo),
    YacimientoKey      INT NOT NULL REFERENCES dbo.DimYacimiento(YacimientoKey),
    MineralKey         INT NOT NULL REFERENCES dbo.DimTipoMineral(MineralKey),
    ToneladasExtraidas DECIMAL(10,2) NOT NULL,
    Ley                DECIMAL(5,2)  NOT NULL,
    ToneladasXLey      AS (ToneladasExtraidas * Ley) PERSISTED,   -- para la ley ponderada
    FechaCarga         DATETIME NOT NULL DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.FactVentas (
    IdVenta           INT PRIMARY KEY,             -- dimension degenerada
    IdTiempo          INT NOT NULL REFERENCES dbo.DimTiempo(IdTiempo),
    ClienteKey        INT NOT NULL REFERENCES dbo.DimCliente(ClienteKey),
    MineralKey        INT NOT NULL REFERENCES dbo.DimTipoMineral(MineralKey),
    ToneladasVendidas DECIMAL(10,2) NOT NULL,
    PrecioAcordado    DECIMAL(12,2) NOT NULL,
    MontoTotal        DECIMAL(14,2) NOT NULL,
    FechaCarga        DATETIME NOT NULL DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.FactGastos (
    IdGasto       INT PRIMARY KEY,               
    IdTiempo      INT NOT NULL REFERENCES dbo.DimTiempo(IdTiempo),
    YacimientoKey INT NOT NULL REFERENCES dbo.DimYacimiento(YacimientoKey),
    TipoGastoKey  INT NOT NULL REFERENCES dbo.DimTipoGasto(TipoGastoKey),
    MontoGasto    DECIMAL(12,2) NOT NULL,
    FechaCarga    DATETIME NOT NULL DEFAULT GETDATE()
);
GO


IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');
GO

IF OBJECT_ID('stg.Extraccion') IS NULL
    CREATE TABLE stg.Extraccion (IdExtraccion INT, Fecha DATE, IdYacimiento INT, IdTipoMineral INT,
        ToneladasExtraidas DECIMAL(10,2), Ley DECIMAL(6,2));
IF OBJECT_ID('stg.Venta') IS NULL
    CREATE TABLE stg.Venta (IdVenta INT, Fecha DATE, IdCliente INT, IdTipoMineral INT,
        ToneladasVendidas DECIMAL(10,2), PrecioAcordado DECIMAL(12,2));
IF OBJECT_ID('stg.Gasto') IS NULL
    CREATE TABLE stg.Gasto (IdGasto INT, Fecha DATE, IdYacimiento INT, IdTipoGasto INT, MontoGasto DECIMAL(12,2));
GO

IF OBJECT_ID('etl.LogCarga') IS NULL
    CREATE TABLE etl.LogCarga (
        IdLog INT IDENTITY(1,1) PRIMARY KEY, Proceso VARCHAR(50) NOT NULL,
        Inicio DATETIME NOT NULL, Fin DATETIME NULL,
        Leidas INT NULL, Cargadas INT NULL, Rechazadas INT NULL,
        Estado VARCHAR(15) NOT NULL, Mensaje VARCHAR(500) NULL);
IF OBJECT_ID('etl.ErrorCarga') IS NULL
    CREATE TABLE etl.ErrorCarga (
        IdError INT IDENTITY(1,1) PRIMARY KEY, IdLog INT NOT NULL, Tabla VARCHAR(20) NOT NULL,
        IdOrigen INT NULL, Regla VARCHAR(30) NOT NULL, Detalle VARCHAR(200) NULL,
        Fecha DATETIME NOT NULL DEFAULT GETDATE());
IF OBJECT_ID('etl.MetricaCalidad') IS NULL
    CREATE TABLE etl.MetricaCalidad (
        IdLog INT NOT NULL, Tabla VARCHAR(20) NOT NULL, Momento VARCHAR(8) NOT NULL,
        Evaluadas INT NOT NULL, Invalidas INT NOT NULL,
        PctValidez AS (CASE WHEN Evaluadas = 0 THEN 100.0 ELSE 100.0 * (Evaluadas - Invalidas) / Evaluadas END));
IF OBJECT_ID('etl.Conciliacion') IS NULL
    CREATE TABLE etl.Conciliacion (
        IdLog INT NOT NULL, Medida VARCHAR(40) NOT NULL,
        ValorOLTP DECIMAL(18,2) NULL, ValorDW DECIMAL(18,2) NULL,
        Diferencia AS (ValorOLTP - ValorDW),
        Estado AS (CASE WHEN ValorOLTP = ValorDW THEN 'OK' ELSE 'DIFERENCIA' END));
GO

SELECT COUNT(*) AS Filas,
       SUM(CASE WHEN IdTipoMineral IS NULL THEN 1 ELSE 0 END) AS NulosMineral,
       MIN(ToneladasExtraidas) AS MinToneladas, MAX(ToneladasExtraidas) AS MaxToneladas,
       MIN(Ley) AS MinLey, MAX(Ley) AS MaxLey,
       COUNT(*) - COUNT(DISTINCT CONCAT(Fecha,'|',IdYacimiento,'|',IdTipoMineral,'|',ToneladasExtraidas,'|',Ley)) AS Duplicados
FROM stg.Extraccion;
GO

CREATE OR ALTER PROCEDURE etl.sp_Cargar_DW
    @InyectarSucios BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdLog INT, @Leidas INT, @Rechazadas INT, @Cargadas INT = 0, @Estado VARCHAR(15) = 'OK';
    INSERT INTO etl.LogCarga (Proceso, Inicio, Estado) VALUES ('sp_Cargar_DW', GETDATE(), 'EN CURSO');
    SET @IdLog = SCOPE_IDENTITY();
    BEGIN TRY
        BEGIN TRANSACTION;

        TRUNCATE TABLE stg.Extraccion; TRUNCATE TABLE stg.Venta; TRUNCATE TABLE stg.Gasto;
        INSERT INTO stg.Extraccion (IdExtraccion, Fecha, IdYacimiento, IdTipoMineral, ToneladasExtraidas, Ley)
        SELECT E.IdExtraccion, T.Fecha, T.IdYacimiento, E.IdTipoMineral, E.ToneladasExtraidas, E.Ley
        FROM GLORE_PERU.dbo.Extraccion E JOIN GLORE_PERU.dbo.Turno T ON T.IdTurno = E.IdTurno;
        INSERT INTO stg.Venta (IdVenta, Fecha, IdCliente, IdTipoMineral, ToneladasVendidas, PrecioAcordado)
        SELECT V.IdVenta, CAST(V.FechaVenta AS DATE), C.IdCliente, L.IdTipoMineral, V.ToneladasVendidas, V.PrecioAcordado
        FROM GLORE_PERU.dbo.Venta V
        JOIN GLORE_PERU.dbo.Contrato C ON C.IdContrato = V.IdContrato
        JOIN GLORE_PERU.dbo.LoteMineral L ON L.IdLote = V.IdLote;
        INSERT INTO stg.Gasto (IdGasto, Fecha, IdYacimiento, IdTipoGasto, MontoGasto)
        SELECT IdGasto, Fecha, IdYacimiento, IdTipoGasto, Monto FROM GLORE_PERU.dbo.Gasto;

        IF @InyectarSucios = 1
        BEGIN
            INSERT INTO stg.Extraccion VALUES
                (9001,'2026-09-01',1,1,-10.00,1.80),  (9002,'2026-09-01',1,NULL,50.00,1.70),
                (9003,'2026-09-01',1,1,120.50,1.85),  (9004,'2026-09-02',2,2,5.00,150.00);
            INSERT INTO stg.Venta VALUES
                (9101,'2026-09-10',999,1,20.00,9200.00), (9102,'2026-09-10',1,1,0.00,9200.00);
        END
        SELECT @Leidas = (SELECT COUNT(*) FROM stg.Extraccion) + (SELECT COUNT(*) FROM stg.Venta) + (SELECT COUNT(*) FROM stg.Gasto);


        CREATE TABLE #rechazo (Tabla VARCHAR(20), IdOrigen INT, Regla VARCHAR(30), Detalle VARCHAR(200));
        INSERT INTO #rechazo
        SELECT 'Extraccion', IdExtraccion, 'R1 toneladas>0', CONCAT('Toneladas=', ToneladasExtraidas)
            FROM stg.Extraccion WHERE ToneladasExtraidas <= 0
        UNION ALL SELECT 'Extraccion', IdExtraccion, 'R2 mineral valido', 'Mineral nulo o inexistente'
            FROM stg.Extraccion S WHERE NOT EXISTS (SELECT 1 FROM GLORE_PERU.dbo.TipoMineral M WHERE M.IdTipoMineral = S.IdTipoMineral)
        UNION ALL SELECT 'Extraccion', IdExtraccion, 'R3 ley 0-100', CONCAT('Ley=', Ley)
            FROM stg.Extraccion WHERE Ley NOT BETWEEN 0 AND 100
        UNION ALL SELECT 'Extraccion', IdExtraccion, 'R4 duplicado', 'Duplicado funcional'
            FROM (SELECT IdExtraccion, ROW_NUMBER() OVER (PARTITION BY Fecha, IdYacimiento, IdTipoMineral, ToneladasExtraidas, Ley ORDER BY IdExtraccion) AS rn
                  FROM stg.Extraccion) d WHERE rn > 1
        UNION ALL SELECT 'Venta', IdVenta, 'R1 toneladas>0', CONCAT('Toneladas=', ToneladasVendidas, ' Precio=', PrecioAcordado)
            FROM stg.Venta WHERE ToneladasVendidas <= 0 OR PrecioAcordado <= 0
        UNION ALL SELECT 'Venta', IdVenta, 'R5 cliente existe', CONCAT('Cliente ', IdCliente, ' no existe')
            FROM stg.Venta S WHERE NOT EXISTS (SELECT 1 FROM GLORE_PERU.dbo.Cliente C WHERE C.IdCliente = S.IdCliente)
        UNION ALL SELECT 'Gasto', IdGasto, 'R1 monto>0', CONCAT('Monto=', MontoGasto)
            FROM stg.Gasto WHERE MontoGasto <= 0;

        SELECT @Rechazadas = COUNT(*) FROM (SELECT DISTINCT Tabla, IdOrigen FROM #rechazo) x;
        INSERT INTO etl.ErrorCarga (IdLog, Tabla, IdOrigen, Regla, Detalle)
        SELECT @IdLog, Tabla, IdOrigen, Regla, Detalle FROM #rechazo;

        INSERT INTO etl.MetricaCalidad (IdLog, Tabla, Momento, Evaluadas, Invalidas)
        SELECT @IdLog, 'Extraccion', 'ANTES', (SELECT COUNT(*) FROM stg.Extraccion), (SELECT COUNT(DISTINCT IdOrigen) FROM #rechazo WHERE Tabla = 'Extraccion')
        UNION ALL SELECT @IdLog, 'Venta', 'ANTES', (SELECT COUNT(*) FROM stg.Venta), (SELECT COUNT(DISTINCT IdOrigen) FROM #rechazo WHERE Tabla = 'Venta')
        UNION ALL SELECT @IdLog, 'Gasto', 'ANTES', (SELECT COUNT(*) FROM stg.Gasto), (SELECT COUNT(DISTINCT IdOrigen) FROM #rechazo WHERE Tabla = 'Gasto');


        INSERT INTO dbo.DimTiempo (IdTiempo, Fecha, Anio, Trimestre, Mes, NombreMes, Dia, DiaSemana)
        SELECT DISTINCT CONVERT(INT, FORMAT(F, 'yyyyMMdd')), F, YEAR(F), DATEPART(QUARTER, F), MONTH(F), DATENAME(MONTH, F), DAY(F), DATENAME(WEEKDAY, F)
        FROM (SELECT Fecha AS F FROM stg.Extraccion UNION SELECT Fecha FROM stg.Venta UNION SELECT Fecha FROM stg.Gasto) X
        WHERE F IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.DimTiempo T WHERE T.Fecha = F);

        MERGE dbo.DimTipoMineral AS d USING GLORE_PERU.dbo.TipoMineral AS s ON d.IdTipoMineral = s.IdTipoMineral
        WHEN MATCHED AND (d.Nombre <> s.Nombre OR d.UnidadMedida <> s.UnidadMedida)
            THEN UPDATE SET d.Nombre = s.Nombre, d.UnidadMedida = s.UnidadMedida
        WHEN NOT MATCHED THEN INSERT (IdTipoMineral, Nombre, UnidadMedida) VALUES (s.IdTipoMineral, s.Nombre, s.UnidadMedida);

        MERGE dbo.DimTipoGasto AS d USING GLORE_PERU.dbo.TipoGasto AS s ON d.IdTipoGasto = s.IdTipoGasto
        WHEN MATCHED AND d.Nombre <> s.Nombre THEN UPDATE SET d.Nombre = s.Nombre
        WHEN NOT MATCHED THEN INSERT (IdTipoGasto, Nombre) VALUES (s.IdTipoGasto, s.Nombre);


        UPDATE d SET FechaFin = CAST(GETDATE() AS DATE), EsActual = 0
        FROM dbo.DimYacimiento d JOIN GLORE_PERU.dbo.Yacimiento s ON s.IdYacimiento = d.IdYacimiento
        WHERE d.EsActual = 1 AND (d.Nombre <> s.Nombre OR d.Ubicacion <> s.Ubicacion OR d.Estado <> s.Estado);
        INSERT INTO dbo.DimYacimiento (IdYacimiento, Nombre, Ubicacion, Estado, FechaInicio)
        SELECT s.IdYacimiento, s.Nombre, s.Ubicacion, s.Estado,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.DimYacimiento x WHERE x.IdYacimiento = s.IdYacimiento)
                    THEN CAST(GETDATE() AS DATE) ELSE '19000101' END
        FROM GLORE_PERU.dbo.Yacimiento s
        WHERE NOT EXISTS (SELECT 1 FROM dbo.DimYacimiento d WHERE d.IdYacimiento = s.IdYacimiento AND d.EsActual = 1);


        SELECT IdCliente, LTRIM(RTRIM(RazonSocial)) AS RazonSocial,
               CASE WHEN LTRIM(RTRIM(Pais)) = 'Peru' THEN 'Perú' ELSE LTRIM(RTRIM(Pais)) END AS Pais,
               CAST(NULL AS VARCHAR(50)) AS Continente
        INTO #cli FROM GLORE_PERU.dbo.Cliente;
        UPDATE #cli SET Continente = CASE Pais WHEN 'China' THEN 'Asia' WHEN 'India' THEN 'Asia'
            WHEN 'España' THEN 'Europa' WHEN 'Suecia' THEN 'Europa'
            WHEN 'Estados Unidos' THEN 'América del Norte' WHEN 'Perú' THEN 'América del Sur' ELSE 'Por clasificar' END;
        UPDATE d SET FechaFin = CAST(GETDATE() AS DATE), EsActual = 0
        FROM dbo.DimCliente d JOIN #cli s ON s.IdCliente = d.IdCliente
        WHERE d.EsActual = 1 AND (d.RazonSocial <> s.RazonSocial OR d.Pais <> s.Pais);
        INSERT INTO dbo.DimCliente (IdCliente, RazonSocial, Pais, Continente, FechaInicio)
        SELECT s.IdCliente, s.RazonSocial, s.Pais, s.Continente,
               CASE WHEN EXISTS (SELECT 1 FROM dbo.DimCliente x WHERE x.IdCliente = s.IdCliente)
                    THEN CAST(GETDATE() AS DATE) ELSE '19000101' END
        FROM #cli s
        WHERE NOT EXISTS (SELECT 1 FROM dbo.DimCliente d WHERE d.IdCliente = s.IdCliente AND d.EsActual = 1);


        INSERT INTO dbo.FactProduccion (IdExtraccion, IdTiempo, YacimientoKey, MineralKey, ToneladasExtraidas, Ley)
        SELECT S.IdExtraccion, CONVERT(INT, FORMAT(S.Fecha, 'yyyyMMdd')), Y.YacimientoKey, M.MineralKey, S.ToneladasExtraidas, S.Ley
        FROM stg.Extraccion S
        JOIN dbo.DimYacimiento Y ON Y.IdYacimiento = S.IdYacimiento AND S.Fecha >= Y.FechaInicio AND (Y.FechaFin IS NULL OR S.Fecha < Y.FechaFin)
        JOIN dbo.DimTipoMineral M ON M.IdTipoMineral = S.IdTipoMineral
        WHERE NOT EXISTS (SELECT 1 FROM #rechazo R WHERE R.Tabla = 'Extraccion' AND R.IdOrigen = S.IdExtraccion)
          AND NOT EXISTS (SELECT 1 FROM dbo.FactProduccion F WHERE F.IdExtraccion = S.IdExtraccion);
        SET @Cargadas += @@ROWCOUNT;

        INSERT INTO dbo.FactVentas (IdVenta, IdTiempo, ClienteKey, MineralKey, ToneladasVendidas, PrecioAcordado, MontoTotal)
        SELECT S.IdVenta, CONVERT(INT, FORMAT(S.Fecha, 'yyyyMMdd')), C.ClienteKey, M.MineralKey, S.ToneladasVendidas, S.PrecioAcordado, S.ToneladasVendidas * S.PrecioAcordado
        FROM stg.Venta S
        JOIN dbo.DimCliente C ON C.IdCliente = S.IdCliente AND S.Fecha >= C.FechaInicio AND (C.FechaFin IS NULL OR S.Fecha < C.FechaFin)
        JOIN dbo.DimTipoMineral M ON M.IdTipoMineral = S.IdTipoMineral
        WHERE NOT EXISTS (SELECT 1 FROM #rechazo R WHERE R.Tabla = 'Venta' AND R.IdOrigen = S.IdVenta)
          AND NOT EXISTS (SELECT 1 FROM dbo.FactVentas F WHERE F.IdVenta = S.IdVenta);
        SET @Cargadas += @@ROWCOUNT;

        INSERT INTO dbo.FactGastos (IdGasto, IdTiempo, YacimientoKey, TipoGastoKey, MontoGasto)
        SELECT S.IdGasto, CONVERT(INT, FORMAT(S.Fecha, 'yyyyMMdd')), Y.YacimientoKey, G.TipoGastoKey, S.MontoGasto
        FROM stg.Gasto S
        JOIN dbo.DimYacimiento Y ON Y.IdYacimiento = S.IdYacimiento AND S.Fecha >= Y.FechaInicio AND (Y.FechaFin IS NULL OR S.Fecha < Y.FechaFin)
        JOIN dbo.DimTipoGasto G ON G.IdTipoGasto = S.IdTipoGasto
        WHERE NOT EXISTS (SELECT 1 FROM #rechazo R WHERE R.Tabla = 'Gasto' AND R.IdOrigen = S.IdGasto)
          AND NOT EXISTS (SELECT 1 FROM dbo.FactGastos F WHERE F.IdGasto = S.IdGasto);
        SET @Cargadas += @@ROWCOUNT;


        INSERT INTO etl.MetricaCalidad (IdLog, Tabla, Momento, Evaluadas, Invalidas)
        SELECT @IdLog, 'Extraccion', 'DESPUES', COUNT(*), ISNULL(SUM(CASE WHEN ToneladasExtraidas <= 0 OR Ley NOT BETWEEN 0 AND 100 THEN 1 ELSE 0 END), 0) FROM dbo.FactProduccion
        UNION ALL SELECT @IdLog, 'Venta', 'DESPUES', COUNT(*), ISNULL(SUM(CASE WHEN ToneladasVendidas <= 0 OR PrecioAcordado <= 0 THEN 1 ELSE 0 END), 0) FROM dbo.FactVentas
        UNION ALL SELECT @IdLog, 'Gasto', 'DESPUES', COUNT(*), ISNULL(SUM(CASE WHEN MontoGasto <= 0 THEN 1 ELSE 0 END), 0) FROM dbo.FactGastos;


        INSERT INTO etl.Conciliacion (IdLog, Medida, ValorOLTP, ValorDW)
        SELECT @IdLog, 'Toneladas extraidas', (SELECT SUM(ToneladasExtraidas) FROM GLORE_PERU.dbo.Extraccion), (SELECT SUM(ToneladasExtraidas) FROM dbo.FactProduccion)
        UNION ALL SELECT @IdLog, 'Toneladas vendidas', (SELECT SUM(ToneladasVendidas) FROM GLORE_PERU.dbo.Venta), (SELECT SUM(ToneladasVendidas) FROM dbo.FactVentas)
        UNION ALL SELECT @IdLog, 'Monto de ventas USD', (SELECT SUM(ToneladasVendidas * PrecioAcordado) FROM GLORE_PERU.dbo.Venta), (SELECT SUM(MontoTotal) FROM dbo.FactVentas)
        UNION ALL SELECT @IdLog, 'Gastos USD', (SELECT SUM(Monto) FROM GLORE_PERU.dbo.Gasto), (SELECT SUM(MontoGasto) FROM dbo.FactGastos);
        IF EXISTS (SELECT 1 FROM etl.Conciliacion WHERE IdLog = @IdLog AND Estado <> 'OK') SET @Estado = 'ALERTA';

        COMMIT TRANSACTION;
        UPDATE etl.LogCarga SET Fin = GETDATE(), Leidas = @Leidas, Cargadas = @Cargadas,
               Rechazadas = @Rechazadas, Estado = @Estado WHERE IdLog = @IdLog;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        UPDATE etl.LogCarga SET Fin = GETDATE(), Estado = 'ERROR', Mensaje = LEFT(ERROR_MESSAGE(), 500) WHERE IdLog = @IdLog;
        THROW;
    END CATCH
END;
GO


CREATE OR ALTER VIEW etl.vw_EstadoCarga AS
SELECT TOP 1 L.IdLog, L.Fin AS UltimaCarga, L.Estado, L.Leidas, L.Cargadas, L.Rechazadas,
       CAST(100.0 * (L.Leidas - L.Rechazadas) / NULLIF(L.Leidas, 0) AS DECIMAL(5,2)) AS PctFilasValidas
FROM etl.LogCarga L
WHERE L.Estado IN ('OK', 'ALERTA')
ORDER BY L.IdLog DESC;
GO


USE msdb;
GO
IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'GLORE_ETL_Diario')
    EXEC dbo.sp_delete_job @job_name = N'GLORE_ETL_Diario';
GO
EXEC master.dbo.xp_create_subdir N'C:\Backups';      -- carpeta del respaldo
EXEC dbo.sp_add_job @job_name = N'GLORE_ETL_Diario', @enabled = 1,
     @description = N'Carga diaria del DW GLORE_PERU_DW y respaldo';
EXEC dbo.sp_add_jobstep @job_name = N'GLORE_ETL_Diario', @step_name = N'1 - Ejecutar ETL',
     @subsystem = N'TSQL', @database_name = N'GLORE_PERU_DW',
     @command = N'EXEC etl.sp_Cargar_DW;', @on_success_action = 3, @on_fail_action = 2;
EXEC dbo.sp_add_jobstep @job_name = N'GLORE_ETL_Diario', @step_name = N'2 - Respaldo del DW',
     @subsystem = N'TSQL', @database_name = N'master',
     @command = N'BACKUP DATABASE GLORE_PERU_DW TO DISK = N''C:\Backups\GLORE_PERU_DW.bak'' WITH INIT, COMPRESSION;',
     @on_success_action = 1, @on_fail_action = 2;
EXEC dbo.sp_add_schedule @schedule_name = N'Diario_2AM', @freq_type = 4, @freq_interval = 1, @active_start_time = 020000;
EXEC dbo.sp_attach_schedule @job_name = N'GLORE_ETL_Diario', @schedule_name = N'Diario_2AM';
EXEC dbo.sp_add_jobserver @job_name = N'GLORE_ETL_Diario';
GO
-- EXEC msdb.dbo.sp_start_job N'GLORE_ETL_Diario';
GO


USE GLORE_PERU_DW;
GO

EXEC etl.sp_Cargar_DW @InyectarSucios = 1;
GO
EXEC etl.sp_Cargar_DW;
GO

SELECT * FROM etl.LogCarga ORDER BY IdLog DESC;
SELECT * FROM etl.MetricaCalidad ORDER BY IdLog DESC, Tabla, Momento;
SELECT * FROM etl.ErrorCarga ORDER BY IdError;
SELECT * FROM etl.Conciliacion ORDER BY IdLog DESC;
SELECT * FROM etl.vw_EstadoCarga;
GO

SELECT (SELECT SUM(ToneladasExtraidas) FROM dbo.FactProduccion) AS ToneladasExtraidas,
       (SELECT SUM(ToneladasVendidas)  FROM dbo.FactVentas)     AS ToneladasVendidas,
       (SELECT SUM(MontoTotal)         FROM dbo.FactVentas)     AS VentasUSD,
       (SELECT SUM(MontoGasto)         FROM dbo.FactGastos)     AS GastosUSD;
GO


SELECT Y.Nombre AS Yacimiento, TM.Nombre AS Mineral, T.Anio,
       SUM(F.ToneladasExtraidas) AS TotalToneladas,
       CAST(SUM(F.ToneladasXLey) / SUM(F.ToneladasExtraidas) AS DECIMAL(6,2)) AS LeyPonderada
FROM dbo.FactProduccion F
JOIN dbo.DimYacimiento Y   ON F.YacimientoKey = Y.YacimientoKey
JOIN dbo.DimTipoMineral TM ON F.MineralKey = TM.MineralKey
JOIN dbo.DimTiempo T       ON F.IdTiempo = T.IdTiempo
GROUP BY Y.Nombre, TM.Nombre, T.Anio
ORDER BY Y.Nombre, TM.Nombre, T.Anio;
GO

SELECT TM.Nombre AS Mineral, T.Anio, T.Trimestre,
       SUM(F.ToneladasVendidas) AS TotalToneladas, SUM(F.MontoTotal) AS MontoTotal
FROM dbo.FactVentas F
JOIN dbo.DimTipoMineral TM ON F.MineralKey = TM.MineralKey
JOIN dbo.DimTiempo T       ON F.IdTiempo = T.IdTiempo
GROUP BY TM.Nombre, T.Anio, T.Trimestre
ORDER BY TM.Nombre, T.Anio, T.Trimestre;
GO

SELECT C.IdCliente, C.RazonSocial, C.Pais,
       SUM(F.MontoTotal) AS MontoTotalComprado, SUM(F.ToneladasVendidas) AS ToneladasTotales
FROM dbo.FactVentas F
JOIN dbo.DimCliente C ON F.ClienteKey = C.ClienteKey
GROUP BY C.IdCliente, C.RazonSocial, C.Pais
ORDER BY MontoTotalComprado DESC;
GO

SELECT Yacimiento, [Cobre], [Oro], [Plata], [Zinc]
FROM (
    SELECT Y.Nombre AS Yacimiento, TM.Nombre AS Mineral, F.ToneladasExtraidas
    FROM dbo.FactProduccion F
    JOIN dbo.DimYacimiento Y   ON F.YacimientoKey = Y.YacimientoKey
    JOIN dbo.DimTipoMineral TM ON F.MineralKey = TM.MineralKey
) AS Origen
PIVOT (SUM(ToneladasExtraidas) FOR Mineral IN ([Cobre], [Oro], [Plata], [Zinc])) AS TablaPivote;
GO

SELECT T.Anio, T.Trimestre, T.Mes, SUM(F.MontoTotal) AS VentasUSD
FROM dbo.FactVentas F JOIN dbo.DimTiempo T ON T.IdTiempo = F.IdTiempo
GROUP BY ROLLUP (T.Anio, T.Trimestre, T.Mes);
GO

SELECT Y.Nombre AS Yacimiento, TG.Nombre AS TipoGasto, SUM(F.MontoGasto) AS GastosUSD
FROM dbo.FactGastos F
JOIN dbo.DimYacimiento Y ON F.YacimientoKey = Y.YacimientoKey
JOIN dbo.DimTipoGasto TG ON F.TipoGastoKey = TG.TipoGastoKey
GROUP BY Y.Nombre, TG.Nombre
ORDER BY Y.Nombre, GastosUSD DESC;
GO

WITH G AS (SELECT YacimientoKey, SUM(MontoGasto) AS Gastos FROM dbo.FactGastos GROUP BY YacimientoKey),
     P AS (SELECT YacimientoKey, SUM(ToneladasExtraidas) AS Toneladas FROM dbo.FactProduccion GROUP BY YacimientoKey)
SELECT Y.Nombre AS Yacimiento, ISNULL(G.Gastos, 0) AS GastosUSD, ISNULL(P.Toneladas, 0) AS Toneladas,
       CAST(G.Gastos / NULLIF(P.Toneladas, 0) AS DECIMAL(12,2)) AS CostoPorTonelada
FROM dbo.DimYacimiento Y
LEFT JOIN G ON G.YacimientoKey = Y.YacimientoKey
LEFT JOIN P ON P.YacimientoKey = Y.YacimientoKey
WHERE Y.EsActual = 1
ORDER BY Y.Nombre;
GO

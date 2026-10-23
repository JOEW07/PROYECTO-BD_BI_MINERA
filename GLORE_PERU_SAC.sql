CREATE DATABASE GLORE_PERU
GO
USE GLORE_PERU
GO

CREATE TABLE TipoMineral (
    IdTipoMineral   INT IDENTITY(1,1) PRIMARY KEY,
    Nombre          VARCHAR(50)  NOT NULL,
    UnidadMedida    VARCHAR(20)  NOT NULL DEFAULT 'Tonelada'
);
GO

CREATE TABLE Yacimiento (
    IdYacimiento    INT IDENTITY(1,1) PRIMARY KEY,
    Nombre          VARCHAR(100) NOT NULL,
    Ubicacion       VARCHAR(150) NOT NULL,
    Estado          VARCHAR(20)  NOT NULL DEFAULT 'Activo'
                    CHECK (Estado IN ('Activo','Inactivo','Mantenimiento'))
);
GO

CREATE TABLE Turno (
    IdTurno         INT IDENTITY(1,1) PRIMARY KEY,
    IdYacimiento    INT NOT NULL,
    Fecha           DATE NOT NULL,
    HoraInicio      TIME NOT NULL,
    HoraFin         TIME NOT NULL,
    Responsable     VARCHAR(100) NOT NULL,
    CONSTRAINT FK_Turno_Yacimiento FOREIGN KEY (IdYacimiento)
        REFERENCES Yacimiento(IdYacimiento)
);
GO

CREATE TABLE Extraccion (
    IdExtraccion        INT IDENTITY(1,1) PRIMARY KEY,
    IdTurno             INT NOT NULL,
    IdTipoMineral       INT NOT NULL,
    ToneladasExtraidas  DECIMAL(10,2) NOT NULL CHECK (ToneladasExtraidas > 0),
    Ley                 DECIMAL(5,2)  NOT NULL CHECK (Ley >= 0),
    FechaRegistro       DATETIME NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Extraccion_Turno FOREIGN KEY (IdTurno)
        REFERENCES Turno(IdTurno),
    CONSTRAINT FK_Extraccion_TipoMineral FOREIGN KEY (IdTipoMineral)
        REFERENCES TipoMineral(IdTipoMineral)
);
GO

CREATE TABLE LoteMineral (
    IdLote              INT IDENTITY(1,1) PRIMARY KEY,
    IdTipoMineral       INT NOT NULL,
    ToneladasTotales    DECIMAL(10,2) NOT NULL CHECK (ToneladasTotales >= 0),
    ToneladasDisponibles DECIMAL(10,2) NOT NULL CHECK (ToneladasDisponibles >= 0),
    FechaProcesamiento  DATE NOT NULL,
    Estado              VARCHAR(20) NOT NULL DEFAULT 'Disponible'
                        CHECK (Estado IN ('Disponible','Vendido','Reservado')),
    CONSTRAINT FK_Lote_TipoMineral FOREIGN KEY (IdTipoMineral)
        REFERENCES TipoMineral(IdTipoMineral)
);
GO

CREATE TABLE ExtraccionLote (
    IdExtraccion    INT NOT NULL,
    IdLote          INT NOT NULL,
    ToneladasAporte DECIMAL(10,2) NOT NULL CHECK (ToneladasAporte > 0),
    PRIMARY KEY (IdExtraccion, IdLote),
    CONSTRAINT FK_EL_Extraccion FOREIGN KEY (IdExtraccion)
        REFERENCES Extraccion(IdExtraccion),
    CONSTRAINT FK_EL_Lote FOREIGN KEY (IdLote)
        REFERENCES LoteMineral(IdLote)
);
GO


CREATE TABLE Cliente (
    IdCliente       INT IDENTITY(1,1) PRIMARY KEY,
    RazonSocial     VARCHAR(150) NOT NULL,
    Pais            VARCHAR(50)  NOT NULL,
    RUC             VARCHAR(20)  NULL,
    Contacto        VARCHAR(100) NULL
);
GO

CREATE TABLE Contrato (
    IdContrato      INT IDENTITY(1,1) PRIMARY KEY,
    IdCliente       INT NOT NULL,
    FechaContrato   DATE NOT NULL,
    Condiciones     VARCHAR(500) NULL,
    Estado          VARCHAR(20) NOT NULL DEFAULT 'Vigente'
                    CHECK (Estado IN ('Vigente','Finalizado','Cancelado')),
    CONSTRAINT FK_Contrato_Cliente FOREIGN KEY (IdCliente)
        REFERENCES Cliente(IdCliente)
);
GO

CREATE TABLE Cotizacion (
    IdCotizacion    INT IDENTITY(1,1) PRIMARY KEY,
    IdTipoMineral   INT NOT NULL,
    Fecha           DATE NOT NULL,
    PrecioPorTonelada DECIMAL(12,2) NOT NULL CHECK (PrecioPorTonelada > 0),
    CONSTRAINT FK_Cotizacion_TipoMineral FOREIGN KEY (IdTipoMineral)
        REFERENCES TipoMineral(IdTipoMineral)
);
GO

CREATE TABLE Venta (
    IdVenta             INT IDENTITY(1,1) PRIMARY KEY,
    IdContrato          INT NOT NULL,
    IdLote              INT NOT NULL,
    ToneladasVendidas   DECIMAL(10,2) NOT NULL CHECK (ToneladasVendidas > 0),
    PrecioAcordado      DECIMAL(12,2) NOT NULL CHECK (PrecioAcordado > 0),
    FechaVenta          DATETIME NOT NULL DEFAULT GETDATE(),
    Destino             VARCHAR(100) NULL,
    CONSTRAINT FK_Venta_Contrato FOREIGN KEY (IdContrato)
        REFERENCES Contrato(IdContrato),
    CONSTRAINT FK_Venta_Lote FOREIGN KEY (IdLote)
        REFERENCES LoteMineral(IdLote)
);
GO


CREATE TABLE Auditoria (
    IdAuditoria     INT IDENTITY(1,1) PRIMARY KEY,
    Tabla           VARCHAR(50)  NOT NULL,
    Operacion       VARCHAR(10)  NOT NULL,
    Descripcion     VARCHAR(300) NOT NULL,
    Usuario         VARCHAR(100) NOT NULL DEFAULT SUSER_SNAME(),
    Fecha           DATETIME NOT NULL DEFAULT GETDATE()
);
GO

CREATE TABLE TipoGasto (
    IdTipoGasto INT IDENTITY(1,1) PRIMARY KEY,
    Nombre      VARCHAR(50) NOT NULL
);
CREATE TABLE Gasto (
    IdGasto      INT IDENTITY(1,1) PRIMARY KEY,
    IdYacimiento INT NOT NULL REFERENCES Yacimiento(IdYacimiento),
    IdTipoGasto  INT NOT NULL REFERENCES TipoGasto(IdTipoGasto),
    Fecha        DATE NOT NULL,
    Monto        DECIMAL(12,2) NOT NULL CHECK (Monto > 0)
);
GO


CREATE OR ALTER PROCEDURE sp_Registrar_Extraccion
    @IdTurno INT,
    @IdTipoMineral INT,
    @Toneladas DECIMAL(10,2),
    @Ley DECIMAL(5,2),
    @IdLoteDestino INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @IdExtraccion INT;

        INSERT INTO Extraccion (IdTurno, IdTipoMineral, ToneladasExtraidas, Ley)
        VALUES (@IdTurno, @IdTipoMineral, @Toneladas, @Ley);

        SET @IdExtraccion = SCOPE_IDENTITY();

        INSERT INTO ExtraccionLote (IdExtraccion, IdLote, ToneladasAporte)
        VALUES (@IdExtraccion, @IdLoteDestino, @Toneladas);

        UPDATE LoteMineral
        SET ToneladasTotales = ToneladasTotales + @Toneladas,
            ToneladasDisponibles = ToneladasDisponibles + @Toneladas
        WHERE IdLote = @IdLoteDestino;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_Registrar_Venta
    @IdContrato INT,
    @IdLote INT,
    @Toneladas DECIMAL(10,2),
    @PrecioAcordado DECIMAL(12,2),
    @Destino VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Disponible DECIMAL(10,2);
        SELECT @Disponible = ToneladasDisponibles FROM LoteMineral WHERE IdLote = @IdLote;

        IF @Disponible IS NULL
        BEGIN
            RAISERROR('El lote especificado no existe.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF @Disponible < @Toneladas
        BEGIN
            DECLARE @DisponibleTexto VARCHAR(20) = CONVERT(VARCHAR(20), @Disponible);
            RAISERROR('Stock insuficiente en el lote. Disponible: %s toneladas.', 16, 1, @DisponibleTexto);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        INSERT INTO Venta (IdContrato, IdLote, ToneladasVendidas, PrecioAcordado, Destino)
        VALUES (@IdContrato, @IdLote, @Toneladas, @PrecioAcordado, @Destino);

        UPDATE LoteMineral
        SET ToneladasDisponibles = ToneladasDisponibles - @Toneladas,
            Estado = CASE WHEN ToneladasDisponibles - @Toneladas <= 0 THEN 'Vendido' ELSE Estado END
        WHERE IdLote = @IdLote;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE sp_ReportesProduccionPorYacimiento
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        Y.Nombre AS Yacimiento,
        TM.Nombre AS Mineral,
        SUM(E.ToneladasExtraidas) AS TotalToneladas,
        AVG(E.Ley) AS LeyPromedio
    FROM Extraccion E
    JOIN Turno T ON E.IdTurno = T.IdTurno
    JOIN Yacimiento Y ON T.IdYacimiento = Y.IdYacimiento
    JOIN TipoMineral TM ON E.IdTipoMineral = TM.IdTipoMineral
    WHERE T.Fecha BETWEEN @FechaInicio AND @FechaFin
    GROUP BY Y.Nombre, TM.Nombre
    ORDER BY Y.Nombre, TM.Nombre;
END;
GO

CREATE OR ALTER PROCEDURE sp_ReportesVentasPorCliente
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        C.RazonSocial,
        C.Pais,
        COUNT(V.IdVenta) AS NumeroVentas,
        SUM(V.ToneladasVendidas) AS TotalToneladasVendidas,
        SUM(V.ToneladasVendidas * V.PrecioAcordado) AS MontoTotal
    FROM Venta V
    JOIN Contrato CT ON V.IdContrato = CT.IdContrato
    JOIN Cliente C ON CT.IdCliente = C.IdCliente
    GROUP BY C.RazonSocial, C.Pais
    ORDER BY MontoTotal DESC;
END;
GO

INSERT INTO TipoMineral (Nombre, UnidadMedida) VALUES
('Cobre','Tonelada'),
('Oro','Tonelada'),
('Plata','Tonelada'),
('Zinc','Tonelada');
GO

INSERT INTO Yacimiento (Nombre, Ubicacion, Estado) VALUES
('Yacimiento Norte','Cajamarca','Activo'),
('Yacimiento Sur','Arequipa','Activo'),
('Yacimiento Central','Junin','Mantenimiento');
GO

INSERT INTO Turno (IdYacimiento, Fecha, HoraInicio, HoraFin, Responsable) VALUES
(1, '2026-09-01', '06:00', '14:00', 'Carlos Ramirez'),
(1, '2026-02-01', '14:00', '22:00', 'Luis Torres'),
(2, '2026-03-02', '06:00', '14:00', 'Maria Quispe'),
(2, '2026-05-03', '06:00', '14:00', 'Jorge Salazar'),
(3, '2026-06-04', '06:00', '14:00', 'Ana Vargas');
GO

INSERT INTO LoteMineral (IdTipoMineral, ToneladasTotales, ToneladasDisponibles, FechaProcesamiento, Estado) VALUES
(1, 0, 0, '2026-01-05', 'Disponible'),
(2, 0, 0, '2026-06-05', 'Disponible'),
(3, 0, 0, '2026-03-06', 'Disponible'),
(4, 0, 0, '2026-03-06', 'Disponible'); 
GO

EXEC sp_Registrar_Extraccion @IdTurno = 1, @IdTipoMineral = 1, @Toneladas = 120.50, @Ley = 1.85, @IdLoteDestino = 1;
EXEC sp_Registrar_Extraccion @IdTurno = 2, @IdTipoMineral = 1, @Toneladas = 95.00,  @Ley = 1.60, @IdLoteDestino = 1;
EXEC sp_Registrar_Extraccion @IdTurno = 3, @IdTipoMineral = 2, @Toneladas = 8.30,   @Ley = 3.20, @IdLoteDestino = 2;
EXEC sp_Registrar_Extraccion @IdTurno = 4, @IdTipoMineral = 3, @Toneladas = 45.75,  @Ley = 2.10, @IdLoteDestino = 3;
GO

INSERT INTO Cliente (RazonSocial, Pais, RUC, Contacto) VALUES
('Trading Metals China Ltd.', 'China', NULL, 'Wei Zhang'),
('European Copper Import S.A.', 'España', NULL, 'Marta Diaz'),
('Andina Comercializadora S.A.C.', 'Peru', '20601234567', 'Pedro Leon');
GO


INSERT INTO Contrato (IdCliente, FechaContrato, Condiciones, Estado) VALUES
(1, '2026-08-15', 'Entrega FOB Callao, pago 30 dias', 'Vigente'),
(2, '2026-08-20', 'Entrega CIF Barcelona, pago 45 dias', 'Vigente'),
(3, '2026-09-01', 'Entrega en planta, pago contado', 'Vigente');
GO

INSERT INTO Cotizacion (IdTipoMineral, Fecha, PrecioPorTonelada) VALUES
(1, '2026-03-01', 9200.00),
(2, '2026-01-01', 68000.00),
(3, '2026-09-01', 780.00),
(4, '2026-06-01', 8500.00)
GO

EXEC sp_Registrar_Venta @IdContrato = 1, @IdLote = 1, @Toneladas = 100.00, @PrecioAcordado = 9200.00, @Destino = 'Shanghai, China';
EXEC sp_Registrar_Venta @IdContrato = 2, @IdLote = 1, @Toneladas = 80.00,  @PrecioAcordado = 9150.00, @Destino = 'Barcelona, España';
EXEC sp_Registrar_Venta @IdContrato = 3, @IdLote = 3, @Toneladas = 45.75, @PrecioAcordado = 780.00,  @Destino = 'Lima, Peru';
GO


INSERT INTO Yacimiento (Nombre, Ubicacion, Estado) VALUES
('Yacimiento Este','Puno','Activo'),
('Yacimiento Oeste','Ancash','Inactivo');
GO

INSERT INTO Turno (IdYacimiento, Fecha, HoraInicio, HoraFin, Responsable) VALUES
(1, '2026-09-05', '06:00', '14:00', 'Rosa Fernandez'),
(1, '2026-10-05', '14:00', '22:00', 'Diego Mamani'),
(2, '2026-01-02', '06:00', '14:00', 'Sofia Chavez'),
(2, '2026-02-07', '14:00', '22:00', 'Miguel Rojas'),
(3, '2026-04-08', '06:00', '14:00', 'Patricia Huaman'),
(4, '2026-05-03', '06:00', '14:00', 'Alberto Cusi'),
(4, '2026-07-10', '14:00', '22:00', 'Elena Paredes'),
(5, '2026-08-11', '06:00', '14:00', 'Ricardo Flores');
GO

INSERT INTO LoteMineral (IdTipoMineral, ToneladasTotales, ToneladasDisponibles, FechaProcesamiento, Estado) VALUES
(4, 0, 0, '2026-09-10', 'Disponible'), 
(1, 0, 0, '2026-09-12', 'Disponible'),  
(3, 0, 0, '2026-04-12', 'Disponible'),  
(1, 0, 0, '2026-07-12', 'Disponible'),  
(2, 0, 0, '2026-09-13', 'Disponible');  
GO

EXEC sp_Registrar_Extraccion @IdTurno = 5,  @IdTipoMineral = 1, @Toneladas = 60.00,  @Ley = 1.75, @IdLoteDestino = 5;
EXEC sp_Registrar_Extraccion @IdTurno = 6,  @IdTipoMineral = 1, @Toneladas = 88.20,  @Ley = 1.90, @IdLoteDestino = 5;
EXEC sp_Registrar_Extraccion @IdTurno = 7,  @IdTipoMineral = 2, @Toneladas = 5.10,   @Ley = 2.95, @IdLoteDestino = 6;
EXEC sp_Registrar_Extraccion @IdTurno = 8,  @IdTipoMineral = 2, @Toneladas = 6.40,   @Ley = 3.10, @IdLoteDestino = 6;
EXEC sp_Registrar_Extraccion @IdTurno = 9,  @IdTipoMineral = 3, @Toneladas = 30.00,  @Ley = 1.80, @IdLoteDestino = 3;
EXEC sp_Registrar_Extraccion @IdTurno = 10, @IdTipoMineral = 4, @Toneladas = 150.00, @Ley = 4.50, @IdLoteDestino = 4;
EXEC sp_Registrar_Extraccion @IdTurno = 11, @IdTipoMineral = 4, @Toneladas = 175.30, @Ley = 4.20, @IdLoteDestino = 4;
EXEC sp_Registrar_Extraccion @IdTurno = 12, @IdTipoMineral = 1, @Toneladas = 40.00,  @Ley = 1.65, @IdLoteDestino = 5;
GO

INSERT INTO Cliente (RazonSocial, Pais, RUC, Contacto) VALUES
('Nordic Mining Group AB', 'Suecia', NULL, 'Erik Lindqvist'),
('Pacific Ores Corp.', 'Estados Unidos', NULL, 'John Miller'),
('Metales del Sur S.A.C.', 'Peru', '20509876543', 'Lucia Mendoza'),
('India Metal Traders Pvt Ltd', 'India', NULL, 'Raj Patel');
GO

INSERT INTO Contrato (IdCliente, FechaContrato, Condiciones, Estado) VALUES
(4, '2026-09-02', 'Entrega FOB Callao, pago 60 dias', 'Vigente'),
(5, '2026-08-04', 'Entrega CIF Los Angeles, pago 30 dias', 'Vigente'),
(6, '2026-10-06', 'Entrega en planta, pago contado', 'Vigente'),
(7, '2026-06-08', 'Entrega FOB Callao, pago 45 dias', 'Vigente');
GO

INSERT INTO Cotizacion (IdTipoMineral, Fecha, PrecioPorTonelada) VALUES
(1, '2026-09-05', 9280.00),
(1, '2026-02-10', 9350.00),
(2, '2026-08-05', 68500.00),
(2, '2026-04-10', 69100.00),
(3, '2026-07-05', 790.00),
(4, '2026-10-05', 3100.00),
(4, '2026-09-10', 3150.00);
GO

EXEC sp_Registrar_Venta @IdContrato = 4, @IdLote = 5, @Toneladas = 100.00, @PrecioAcordado = 9280.00,  @Destino = 'Estocolmo, Suecia';
EXEC sp_Registrar_Venta @IdContrato = 5, @IdLote = 4, @Toneladas = 150.00, @PrecioAcordado = 3100.00,  @Destino = 'Los Angeles, EEUU';
EXEC sp_Registrar_Venta @IdContrato = 6, @IdLote = 6, @Toneladas = 8.00,   @PrecioAcordado = 68500.00, @Destino = 'Lima, Peru';
EXEC sp_Registrar_Venta @IdContrato = 7, @IdLote = 4, @Toneladas = 100.00, @PrecioAcordado = 3120.00,  @Destino = 'Mumbai, India';
GO


INSERT INTO TipoGasto (Nombre) VALUES ('Combustible'), ('Mantenimiento'), ('Planilla'), ('Explosivos');
INSERT INTO Gasto (IdYacimiento, IdTipoGasto, Fecha, Monto) VALUES
(1, 1, '2026-09-01', 18500.00), (1, 2, '2026-09-01', 7200.00),
(1, 3, '2026-01-05', 42000.00), (2, 1, '2026-02-02', 15300.00),
(2, 4, '2026-04-03', 9800.00),  (2, 3, '2026-01-06', 38000.00),
(3, 2, '2026-05-08', 5400.00),  (4, 1, '2026-07-09', 12100.00);
GO


UPDATE v SET FechaVenta = d.Fecha
FROM Venta v
JOIN (VALUES (1,'20260306'), (2,'20260208'), (3,'20261009'), (4,'20260614'),
             (5,'20260515'), (6,'20260616'), (7,'20260718')) AS d(IdContrato, Fecha)
  ON d.IdContrato = v.IdContrato;
GO

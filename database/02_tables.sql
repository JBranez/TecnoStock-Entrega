/* Tablas principales. Todas las relaciones conservan el historial. */
IF OBJECT_ID(N'dbo.Usuarios', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Usuarios
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Usuarios PRIMARY KEY,
        Username NVARCHAR(50) NOT NULL,
        NombreCompleto NVARCHAR(100) NOT NULL,
        PasswordHash NVARCHAR(255) NOT NULL,
        Activo BIT NOT NULL CONSTRAINT DF_Usuarios_Activo DEFAULT (1),
        FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_Usuarios_FechaCreacion DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_Usuarios_Username UNIQUE (Username),
        CONSTRAINT CK_Usuarios_Username_NoVacio CHECK (LEN(LTRIM(RTRIM(Username))) > 0),
        CONSTRAINT CK_Usuarios_Nombre_NoVacio CHECK (LEN(LTRIM(RTRIM(NombreCompleto))) > 0)
    );
END;
GO

IF OBJECT_ID(N'dbo.Categorias', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Categorias
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Categorias PRIMARY KEY,
        Nombre NVARCHAR(80) NOT NULL,
        Descripcion NVARCHAR(250) NULL,
        FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_Categorias_FechaCreacion DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_Categorias_Nombre UNIQUE (Nombre),
        CONSTRAINT CK_Categorias_Nombre_NoVacio CHECK (LEN(LTRIM(RTRIM(Nombre))) > 0)
    );
END;
GO

IF OBJECT_ID(N'dbo.Productos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Productos
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Productos PRIMARY KEY,
        Codigo NVARCHAR(30) NOT NULL,
        Nombre NVARCHAR(120) NOT NULL,
        Descripcion NVARCHAR(500) NULL,
        CategoriaId INT NOT NULL,
        PrecioCompra DECIMAL(12,2) NOT NULL,
        PrecioVenta DECIMAL(12,2) NOT NULL,
        StockActual INT NOT NULL CONSTRAINT DF_Productos_StockActual DEFAULT (0),
        StockMinimo INT NOT NULL CONSTRAINT DF_Productos_StockMinimo DEFAULT (0),
        Activo BIT NOT NULL CONSTRAINT DF_Productos_Activo DEFAULT (1),
        FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_Productos_FechaCreacion DEFAULT (SYSDATETIME()),
        FechaActualizacion DATETIME2(0) NULL,
        CONSTRAINT UQ_Productos_Codigo UNIQUE (Codigo),
        CONSTRAINT FK_Productos_Categorias FOREIGN KEY (CategoriaId) REFERENCES dbo.Categorias(Id),
        CONSTRAINT CK_Productos_Codigo_NoVacio CHECK (LEN(LTRIM(RTRIM(Codigo))) > 0),
        CONSTRAINT CK_Productos_Nombre_NoVacio CHECK (LEN(LTRIM(RTRIM(Nombre))) > 0),
        CONSTRAINT CK_Productos_PrecioCompra CHECK (PrecioCompra > 0),
        CONSTRAINT CK_Productos_PrecioVenta CHECK (PrecioVenta > 0),
        CONSTRAINT CK_Productos_StockActual CHECK (StockActual >= 0),
        CONSTRAINT CK_Productos_StockMinimo CHECK (StockMinimo >= 0)
    );
END;
GO

IF OBJECT_ID(N'dbo.MovimientosInventario', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.MovimientosInventario
    (
        Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_MovimientosInventario PRIMARY KEY,
        ProductoId INT NOT NULL,
        TipoMovimiento VARCHAR(10) NOT NULL,
        Cantidad INT NOT NULL,
        FechaMovimiento DATE NOT NULL,
        Motivo NVARCHAR(200) NOT NULL,
        StockAnterior INT NOT NULL,
        StockPosterior INT NOT NULL,
        UsuarioId INT NOT NULL,
        FechaRegistro DATETIME2(0) NOT NULL CONSTRAINT DF_Movimientos_FechaRegistro DEFAULT (SYSDATETIME()),
        CONSTRAINT FK_Movimientos_Productos FOREIGN KEY (ProductoId) REFERENCES dbo.Productos(Id),
        CONSTRAINT FK_Movimientos_Usuarios FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(Id),
        CONSTRAINT CK_Movimientos_Tipo CHECK (TipoMovimiento IN ('ENTRADA', 'SALIDA')),
        CONSTRAINT CK_Movimientos_Cantidad CHECK (Cantidad > 0),
        CONSTRAINT CK_Movimientos_StockAnterior CHECK (StockAnterior >= 0),
        CONSTRAINT CK_Movimientos_StockPosterior CHECK (StockPosterior >= 0),
        CONSTRAINT CK_Movimientos_Motivo CHECK (LEN(LTRIM(RTRIM(Motivo))) > 0),
        CONSTRAINT CK_Movimientos_ConsistenciaStock CHECK
        (
            (TipoMovimiento = 'ENTRADA' AND StockPosterior = StockAnterior + Cantidad)
            OR
            (TipoMovimiento = 'SALIDA' AND StockPosterior = StockAnterior - Cantidad)
        )
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Movimiento_RegistrarEntrada
    @ProductoId INT,
    @Cantidad INT,
    @FechaMovimiento DATE,
    @Motivo NVARCHAR(200),
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Motivo = LTRIM(RTRIM(@Motivo));
    IF @Cantidad IS NULL OR @Cantidad <= 0 OR @FechaMovimiento IS NULL
       OR @Motivo IS NULL OR LEN(@Motivo) = 0 OR LEN(@Motivo) > 200
        THROW 50010, N'DATOS_INVALIDOS|La cantidad, fecha y motivo de la entrada son obligatorios; la cantidad debe ser mayor que cero.', 1;
    IF @FechaMovimiento > CONVERT(DATE, SYSDATETIME())
        THROW 50010, N'DATOS_INVALIDOS|La fecha del movimiento no puede ser futura.', 1;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Stock INT, @Activo BIT, @NuevoStock BIGINT, @MovimientoId INT;
        SELECT @Stock = StockActual, @Activo = Activo
        FROM dbo.Productos WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @ProductoId;

        IF @Stock IS NULL
            THROW 50001, N'PRODUCTO_NO_ENCONTRADO|El producto no existe.', 1;
        IF @Activo = 0
            THROW 50004, N'PRODUCTO_INACTIVO|No se pueden registrar movimientos de un producto inactivo.', 1;
        SET @NuevoStock = CONVERT(BIGINT, @Stock) + @Cantidad;
        IF @NuevoStock > 2147483647
            THROW 50010, N'DATOS_INVALIDOS|La cantidad supera el máximo de existencias permitido.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Id = @UsuarioId AND Activo = 1)
            THROW 50015, N'USUARIO_NO_ENCONTRADO|El usuario no existe o está inactivo.', 1;

        UPDATE dbo.Productos
           SET StockActual = CONVERT(INT, @NuevoStock), FechaActualizacion = SYSDATETIME()
         WHERE Id = @ProductoId;

        INSERT INTO dbo.MovimientosInventario
            (ProductoId, TipoMovimiento, Cantidad, FechaMovimiento, Motivo,
             StockAnterior, StockPosterior, UsuarioId)
        VALUES
            (@ProductoId, 'ENTRADA', @Cantidad, @FechaMovimiento, @Motivo,
             @Stock, CONVERT(INT, @NuevoStock), @UsuarioId);
        SET @MovimientoId = CONVERT(INT, SCOPE_IDENTITY());
        COMMIT TRAN;

        SELECT m.Id, m.ProductoId, p.Codigo AS ProductoCodigo, p.Nombre AS ProductoNombre,
               m.TipoMovimiento, m.Cantidad, m.FechaMovimiento, m.Motivo,
               m.StockAnterior, m.StockPosterior, m.UsuarioId,
               u.NombreCompleto AS UsuarioNombre, m.FechaRegistro
        FROM dbo.MovimientosInventario m
        INNER JOIN dbo.Productos p ON p.Id = m.ProductoId
        INNER JOIN dbo.Usuarios u ON u.Id = m.UsuarioId
        WHERE m.Id = @MovimientoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Movimiento_RegistrarSalida
    @ProductoId INT,
    @Cantidad INT,
    @FechaMovimiento DATE,
    @Motivo NVARCHAR(200),
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Motivo = LTRIM(RTRIM(@Motivo));
    IF @Cantidad IS NULL OR @Cantidad <= 0 OR @FechaMovimiento IS NULL
       OR @Motivo IS NULL OR LEN(@Motivo) = 0 OR LEN(@Motivo) > 200
        THROW 50010, N'DATOS_INVALIDOS|La cantidad, fecha y motivo de la salida son obligatorios; la cantidad debe ser mayor que cero.', 1;
    IF @FechaMovimiento > CONVERT(DATE, SYSDATETIME())
        THROW 50010, N'DATOS_INVALIDOS|La fecha del movimiento no puede ser futura.', 1;

    BEGIN TRY
        BEGIN TRAN;
        DECLARE @Stock INT, @Activo BIT, @NuevoStock INT, @MovimientoId INT, @Msg NVARCHAR(200);
        SELECT @Stock = StockActual, @Activo = Activo
        FROM dbo.Productos WITH (UPDLOCK, ROWLOCK)
        WHERE Id = @ProductoId;

        IF @Stock IS NULL
            THROW 50001, N'PRODUCTO_NO_ENCONTRADO|El producto no existe.', 1;
        IF @Activo = 0
            THROW 50004, N'PRODUCTO_INACTIVO|No se pueden registrar movimientos de un producto inactivo.', 1;
        IF @Cantidad > @Stock
        BEGIN
            SET @Msg = CONCAT(N'STOCK_INSUFICIENTE|Stock disponible: ', @Stock, N'.');
            THROW 50003, @Msg, 1;
        END;
        IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Id = @UsuarioId AND Activo = 1)
            THROW 50015, N'USUARIO_NO_ENCONTRADO|El usuario no existe o está inactivo.', 1;

        SET @NuevoStock = @Stock - @Cantidad;
        UPDATE dbo.Productos
           SET StockActual = @NuevoStock, FechaActualizacion = SYSDATETIME()
         WHERE Id = @ProductoId;

        INSERT INTO dbo.MovimientosInventario
            (ProductoId, TipoMovimiento, Cantidad, FechaMovimiento, Motivo,
             StockAnterior, StockPosterior, UsuarioId)
        VALUES
            (@ProductoId, 'SALIDA', @Cantidad, @FechaMovimiento, @Motivo,
             @Stock, @NuevoStock, @UsuarioId);
        SET @MovimientoId = CONVERT(INT, SCOPE_IDENTITY());
        COMMIT TRAN;

        SELECT m.Id, m.ProductoId, p.Codigo AS ProductoCodigo, p.Nombre AS ProductoNombre,
               m.TipoMovimiento, m.Cantidad, m.FechaMovimiento, m.Motivo,
               m.StockAnterior, m.StockPosterior, m.UsuarioId,
               u.NombreCompleto AS UsuarioNombre, m.FechaRegistro
        FROM dbo.MovimientosInventario m
        INNER JOIN dbo.Productos p ON p.Id = m.ProductoId
        INNER JOIN dbo.Usuarios u ON u.Id = m.UsuarioId
        WHERE m.Id = @MovimientoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Movimiento_Listar
    @ProductoId INT = NULL,
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL,
    @Tipo VARCHAR(10) = NULL,
    @Pagina INT = 1,
    @TamanoPagina INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Pagina < 1 OR @TamanoPagina < 1 OR @TamanoPagina > 100
        THROW 50010, N'DATOS_INVALIDOS|La paginación debe ser positiva y el tamaño máximo es 100.', 1;
    IF @FechaDesde IS NOT NULL AND @FechaHasta IS NOT NULL AND @FechaDesde > @FechaHasta
        THROW 50010, N'DATOS_INVALIDOS|La fecha inicial no puede ser posterior a la fecha final.', 1;
    IF @Tipo IS NOT NULL AND @Tipo NOT IN ('ENTRADA', 'SALIDA')
        THROW 50010, N'DATOS_INVALIDOS|El tipo debe ser ENTRADA o SALIDA.', 1;

    DECLARE @Total INT;
    SELECT @Total = COUNT(1)
    FROM dbo.MovimientosInventario m
    WHERE (@ProductoId IS NULL OR m.ProductoId = @ProductoId)
      AND (@FechaDesde IS NULL OR m.FechaMovimiento >= @FechaDesde)
      AND (@FechaHasta IS NULL OR m.FechaMovimiento < DATEADD(DAY, 1, @FechaHasta))
      AND (@Tipo IS NULL OR m.TipoMovimiento = @Tipo);
    SELECT @Total AS Total;

    SELECT m.Id, m.ProductoId, p.Codigo AS ProductoCodigo, p.Nombre AS ProductoNombre,
           m.TipoMovimiento, m.Cantidad, m.FechaMovimiento, m.Motivo,
           m.StockAnterior, m.StockPosterior, m.UsuarioId,
           u.NombreCompleto AS UsuarioNombre, m.FechaRegistro, COUNT(1) OVER() AS Total
    FROM dbo.MovimientosInventario m
    INNER JOIN dbo.Productos p ON p.Id = m.ProductoId
    INNER JOIN dbo.Usuarios u ON u.Id = m.UsuarioId
    WHERE (@ProductoId IS NULL OR m.ProductoId = @ProductoId)
      AND (@FechaDesde IS NULL OR m.FechaMovimiento >= @FechaDesde)
      AND (@FechaHasta IS NULL OR m.FechaMovimiento < DATEADD(DAY, 1, @FechaHasta))
      AND (@Tipo IS NULL OR m.TipoMovimiento = @Tipo)
    ORDER BY m.Id DESC
    OFFSET (@Pagina - 1) * @TamanoPagina ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

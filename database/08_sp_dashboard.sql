CREATE OR ALTER PROCEDURE dbo.usp_Dashboard_ObtenerIndicadores
    @FechaDesde DATE = NULL,
    @FechaHasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @FechaDesde IS NOT NULL AND @FechaHasta IS NOT NULL AND @FechaDesde > @FechaHasta
        THROW 50010, N'DATOS_INVALIDOS|La fecha inicial no puede ser posterior a la fecha final.', 1;

    /* Si no se envía rango, se informa el acumulado histórico. */
    SELECT
        (SELECT COUNT(1) FROM dbo.Productos WHERE Activo = 1) AS ProductosActivos,
        (SELECT COUNT(1) FROM dbo.Productos WHERE Activo = 1 AND StockActual <= StockMinimo) AS ProductosStockBajo,
        (SELECT COALESCE(SUM(CONVERT(DECIMAL(19,2), StockActual) * PrecioCompra), 0)
         FROM dbo.Productos WHERE Activo = 1) AS ValorReferencial,
        (SELECT COUNT(1) FROM dbo.MovimientosInventario m
         WHERE m.TipoMovimiento = 'ENTRADA'
           AND (@FechaDesde IS NULL OR m.FechaMovimiento >= @FechaDesde)
           AND (@FechaHasta IS NULL OR m.FechaMovimiento < DATEADD(DAY, 1, @FechaHasta))) AS TotalEntradas,
        (SELECT COUNT(1) FROM dbo.MovimientosInventario m
         WHERE m.TipoMovimiento = 'SALIDA'
           AND (@FechaDesde IS NULL OR m.FechaMovimiento >= @FechaDesde)
           AND (@FechaHasta IS NULL OR m.FechaMovimiento < DATEADD(DAY, 1, @FechaHasta))) AS TotalSalidas,
        (SELECT COUNT(1) FROM dbo.MovimientosInventario m
         WHERE (@FechaDesde IS NULL OR m.FechaMovimiento >= @FechaDesde)
           AND (@FechaHasta IS NULL OR m.FechaMovimiento < DATEADD(DAY, 1, @FechaHasta))) AS TotalMovimientos,
        @FechaDesde AS FechaDesde,
        @FechaHasta AS FechaHasta;
END;
GO

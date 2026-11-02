/* Índices para búsquedas frecuentes y consultas de historial. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Productos_Nombre' AND object_id = OBJECT_ID(N'dbo.Productos'))
    CREATE INDEX IX_Productos_Nombre ON dbo.Productos(Nombre);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Productos_CategoriaId' AND object_id = OBJECT_ID(N'dbo.Productos'))
    CREATE INDEX IX_Productos_CategoriaId ON dbo.Productos(CategoriaId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Movimientos_Producto_Fecha' AND object_id = OBJECT_ID(N'dbo.MovimientosInventario'))
    CREATE INDEX IX_Movimientos_Producto_Fecha ON dbo.MovimientosInventario(ProductoId, FechaMovimiento DESC, Id DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Movimientos_Fecha' AND object_id = OBJECT_ID(N'dbo.MovimientosInventario'))
    CREATE INDEX IX_Movimientos_Fecha ON dbo.MovimientosInventario(FechaMovimiento DESC, Id DESC);
GO

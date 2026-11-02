CREATE OR ALTER PROCEDURE dbo.usp_Producto_Crear
    @Codigo NVARCHAR(30),
    @Nombre NVARCHAR(120),
    @Descripcion NVARCHAR(500) = NULL,
    @CategoriaId INT,
    @PrecioCompra DECIMAL(12,2),
    @PrecioVenta DECIMAL(12,2),
    @StockMinimo INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Codigo = UPPER(LTRIM(RTRIM(@Codigo)));
    SET @Nombre = LTRIM(RTRIM(@Nombre));
    IF @Descripcion IS NOT NULL SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');

    IF @Codigo IS NULL OR LEN(@Codigo) = 0 OR LEN(@Codigo) > 30
       OR @Nombre IS NULL OR LEN(@Nombre) = 0 OR LEN(@Nombre) > 120
       OR @PrecioCompra IS NULL OR @PrecioCompra <= 0
       OR @PrecioVenta IS NULL OR @PrecioVenta <= 0
       OR @StockMinimo IS NULL OR @StockMinimo < 0
        THROW 50010, N'DATOS_INVALIDOS|Revisa código, nombre, precios y stock mínimo del producto.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE Id = @CategoriaId)
        THROW 50013, N'CATEGORIA_NO_ENCONTRADA|La categoría seleccionada no existe.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Productos WHERE Codigo = @Codigo)
        THROW 50002, N'CODIGO_DUPLICADO|Ya existe un producto con ese código.', 1;

    INSERT INTO dbo.Productos
        (Codigo, Nombre, Descripcion, CategoriaId, PrecioCompra, PrecioVenta, StockMinimo)
    VALUES
        (@Codigo, @Nombre, @Descripcion, @CategoriaId, @PrecioCompra, @PrecioVenta, @StockMinimo);

    SELECT p.Id, p.Codigo, p.Nombre, p.Descripcion, p.CategoriaId, c.Nombre AS CategoriaNombre,
           p.PrecioCompra, p.PrecioVenta, p.StockActual, p.StockMinimo, p.Activo,
           p.FechaCreacion, p.FechaActualizacion
    FROM dbo.Productos p INNER JOIN dbo.Categorias c ON c.Id = p.CategoriaId
    WHERE p.Id = CONVERT(INT, SCOPE_IDENTITY());
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Producto_Actualizar
    @Id INT,
    @Codigo NVARCHAR(30),
    @Nombre NVARCHAR(120),
    @Descripcion NVARCHAR(500) = NULL,
    @CategoriaId INT,
    @PrecioCompra DECIMAL(12,2),
    @PrecioVenta DECIMAL(12,2),
    @StockMinimo INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Codigo = UPPER(LTRIM(RTRIM(@Codigo)));
    SET @Nombre = LTRIM(RTRIM(@Nombre));
    IF @Descripcion IS NOT NULL SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');

    IF @Codigo IS NULL OR LEN(@Codigo) = 0 OR LEN(@Codigo) > 30
       OR @Nombre IS NULL OR LEN(@Nombre) = 0 OR LEN(@Nombre) > 120
       OR @PrecioCompra IS NULL OR @PrecioCompra <= 0
       OR @PrecioVenta IS NULL OR @PrecioVenta <= 0
       OR @StockMinimo IS NULL OR @StockMinimo < 0
        THROW 50010, N'DATOS_INVALIDOS|Revisa código, nombre, precios y stock mínimo del producto.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Id = @Id)
        THROW 50001, N'PRODUCTO_NO_ENCONTRADO|El producto solicitado no existe.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE Id = @CategoriaId)
        THROW 50013, N'CATEGORIA_NO_ENCONTRADA|La categoría seleccionada no existe.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Productos WHERE Codigo = @Codigo AND Id <> @Id)
        THROW 50002, N'CODIGO_DUPLICADO|Ya existe un producto con ese código.', 1;

    UPDATE dbo.Productos
       SET Codigo = @Codigo, Nombre = @Nombre, Descripcion = @Descripcion,
           CategoriaId = @CategoriaId, PrecioCompra = @PrecioCompra,
           PrecioVenta = @PrecioVenta, StockMinimo = @StockMinimo,
           FechaActualizacion = SYSDATETIME()
     WHERE Id = @Id;

    SELECT p.Id, p.Codigo, p.Nombre, p.Descripcion, p.CategoriaId, c.Nombre AS CategoriaNombre,
           p.PrecioCompra, p.PrecioVenta, p.StockActual, p.StockMinimo, p.Activo,
           p.FechaCreacion, p.FechaActualizacion
    FROM dbo.Productos p INNER JOIN dbo.Categorias c ON c.Id = p.CategoriaId
    WHERE p.Id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Producto_ObtenerPorId
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SELECT p.Id, p.Codigo, p.Nombre, p.Descripcion, p.CategoriaId, c.Nombre AS CategoriaNombre,
           p.PrecioCompra, p.PrecioVenta, p.StockActual, p.StockMinimo, p.Activo,
           p.FechaCreacion, p.FechaActualizacion
    FROM dbo.Productos p INNER JOIN dbo.Categorias c ON c.Id = p.CategoriaId
    WHERE p.Id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Producto_Listar
    @Busqueda NVARCHAR(120) = NULL,
    @CategoriaId INT = NULL,
    @Estado NVARCHAR(10) = N'activos',
    @Pagina INT = 1,
    @TamanoPagina INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Busqueda = NULLIF(LTRIM(RTRIM(@Busqueda)), N'');
    IF @Pagina < 1 OR @TamanoPagina < 1 OR @TamanoPagina > 100
        THROW 50010, N'DATOS_INVALIDOS|La paginación debe ser positiva y el tamaño máximo es 100.', 1;
    IF @Estado NOT IN (N'activos', N'inactivos', N'todos')
        THROW 50010, N'DATOS_INVALIDOS|El estado debe ser activos, inactivos o todos.', 1;

    DECLARE @Total INT;
    SELECT @Total = COUNT(1)
    FROM dbo.Productos p
    WHERE (@Busqueda IS NULL OR p.Codigo LIKE N'%' + @Busqueda + N'%' OR p.Nombre LIKE N'%' + @Busqueda + N'%')
      AND (@CategoriaId IS NULL OR p.CategoriaId = @CategoriaId)
      AND (@Estado = N'todos' OR (@Estado = N'activos' AND p.Activo = 1) OR (@Estado = N'inactivos' AND p.Activo = 0));
    SELECT @Total AS Total;

    SELECT p.Id, p.Codigo, p.Nombre, p.Descripcion, p.CategoriaId, c.Nombre AS CategoriaNombre,
           p.PrecioCompra, p.PrecioVenta, p.StockActual, p.StockMinimo, p.Activo,
           p.FechaCreacion, p.FechaActualizacion, COUNT(1) OVER() AS Total
    FROM dbo.Productos p INNER JOIN dbo.Categorias c ON c.Id = p.CategoriaId
    WHERE (@Busqueda IS NULL OR p.Codigo LIKE N'%' + @Busqueda + N'%' OR p.Nombre LIKE N'%' + @Busqueda + N'%')
      AND (@CategoriaId IS NULL OR p.CategoriaId = @CategoriaId)
      AND (@Estado = N'todos' OR (@Estado = N'activos' AND p.Activo = 1) OR (@Estado = N'inactivos' AND p.Activo = 0))
    ORDER BY p.Nombre, p.Id
    OFFSET (@Pagina - 1) * @TamanoPagina ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Producto_CambiarEstado
    @Id INT,
    @Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Id = @Id)
        THROW 50001, N'PRODUCTO_NO_ENCONTRADO|El producto solicitado no existe.', 1;
    UPDATE dbo.Productos SET Activo = @Activo, FechaActualizacion = SYSDATETIME() WHERE Id = @Id;
    SELECT p.Id, p.Codigo, p.Nombre, p.Descripcion, p.CategoriaId, c.Nombre AS CategoriaNombre,
           p.PrecioCompra, p.PrecioVenta, p.StockActual, p.StockMinimo, p.Activo,
           p.FechaCreacion, p.FechaActualizacion
    FROM dbo.Productos p INNER JOIN dbo.Categorias c ON c.Id = p.CategoriaId
    WHERE p.Id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Producto_Eliminar
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        IF NOT EXISTS (SELECT 1 FROM dbo.Productos WITH (UPDLOCK, HOLDLOCK) WHERE Id = @Id)
            THROW 50001, N'PRODUCTO_NO_ENCONTRADO|El producto solicitado no existe.', 1;
        IF EXISTS (SELECT 1 FROM dbo.MovimientosInventario WHERE ProductoId = @Id)
            THROW 50014, N'PRODUCTO_CON_MOVIMIENTOS|El producto tiene historial; desactívalo en lugar de eliminarlo.', 1;
        DELETE FROM dbo.Productos WHERE Id = @Id;
        COMMIT TRAN;
        SELECT @Id AS Id, CAST(1 AS BIT) AS Eliminado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Producto_ListarStockBajo
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SELECT p.Id, p.Codigo, p.Nombre, p.Descripcion, p.CategoriaId, c.Nombre AS CategoriaNombre,
           p.PrecioCompra, p.PrecioVenta, p.StockActual, p.StockMinimo, p.Activo,
           p.FechaCreacion, p.FechaActualizacion
    FROM dbo.Productos p INNER JOIN dbo.Categorias c ON c.Id = p.CategoriaId
    WHERE p.Activo = 1 AND p.StockActual <= p.StockMinimo
    ORDER BY (p.StockMinimo - p.StockActual) DESC, p.Nombre;
END;
GO

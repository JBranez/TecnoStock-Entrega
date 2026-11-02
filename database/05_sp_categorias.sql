CREATE OR ALTER PROCEDURE dbo.usp_Categoria_Crear
    @Nombre NVARCHAR(80),
    @Descripcion NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Nombre = LTRIM(RTRIM(@Nombre));
    IF @Nombre IS NULL OR LEN(@Nombre) = 0 OR LEN(@Nombre) > 80
        THROW 50010, N'DATOS_INVALIDOS|El nombre de la categoría es obligatorio (máximo 80 caracteres).', 1;
    IF @Descripcion IS NOT NULL SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');
    IF EXISTS (SELECT 1 FROM dbo.Categorias WHERE Nombre = @Nombre)
        THROW 50002, N'CATEGORIA_DUPLICADA|Ya existe una categoría con ese nombre.', 1;

    INSERT INTO dbo.Categorias (Nombre, Descripcion) VALUES (@Nombre, @Descripcion);
    SELECT Id, Nombre, Descripcion, FechaCreacion
    FROM dbo.Categorias WHERE Id = CONVERT(INT, SCOPE_IDENTITY());
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Categoria_Actualizar
    @Id INT,
    @Nombre NVARCHAR(80),
    @Descripcion NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Nombre = LTRIM(RTRIM(@Nombre));
    IF @Nombre IS NULL OR LEN(@Nombre) = 0 OR LEN(@Nombre) > 80
        THROW 50010, N'DATOS_INVALIDOS|El nombre de la categoría es obligatorio (máximo 80 caracteres).', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WHERE Id = @Id)
        THROW 50011, N'CATEGORIA_NO_ENCONTRADA|La categoría solicitada no existe.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Categorias WHERE Nombre = @Nombre AND Id <> @Id)
        THROW 50002, N'CATEGORIA_DUPLICADA|Ya existe una categoría con ese nombre.', 1;
    IF @Descripcion IS NOT NULL SET @Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), N'');

    UPDATE dbo.Categorias SET Nombre = @Nombre, Descripcion = @Descripcion WHERE Id = @Id;
    SELECT Id, Nombre, Descripcion, FechaCreacion FROM dbo.Categorias WHERE Id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Categoria_ObtenerPorId
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SELECT Id, Nombre, Descripcion, FechaCreacion FROM dbo.Categorias WHERE Id = @Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Categoria_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SELECT Id, Nombre, Descripcion, FechaCreacion
    FROM dbo.Categorias
    ORDER BY Nombre, Id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Categoria_Eliminar
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRAN;
        IF NOT EXISTS (SELECT 1 FROM dbo.Categorias WITH (UPDLOCK, HOLDLOCK) WHERE Id = @Id)
            THROW 50011, N'CATEGORIA_NO_ENCONTRADA|La categoría solicitada no existe.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Productos WHERE CategoriaId = @Id)
            THROW 50012, N'CATEGORIA_CON_PRODUCTOS|No se puede eliminar una categoría que tiene productos asociados.', 1;
        DELETE FROM dbo.Categorias WHERE Id = @Id;
        COMMIT TRAN;
        SELECT @Id AS Id, CAST(1 AS BIT) AS Eliminado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH;
END;
GO

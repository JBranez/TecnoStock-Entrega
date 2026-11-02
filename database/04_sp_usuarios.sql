CREATE OR ALTER PROCEDURE dbo.usp_Usuario_ObtenerPorUsername
    @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SELECT Id, Username, NombreCompleto, PasswordHash, Activo, FechaCreacion
    FROM dbo.Usuarios
    WHERE Username = LTRIM(RTRIM(@Username));
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Usuario_Crear
    @Username NVARCHAR(50),
    @NombreCompleto NVARCHAR(100),
    @PasswordHash NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET @Username = LTRIM(RTRIM(@Username));
    SET @NombreCompleto = LTRIM(RTRIM(@NombreCompleto));

    IF @Username IS NULL OR LEN(@Username) = 0 OR LEN(@Username) > 50
       OR @NombreCompleto IS NULL OR LEN(@NombreCompleto) = 0 OR LEN(@NombreCompleto) > 100
       OR @PasswordHash IS NULL OR LEN(@PasswordHash) = 0 OR LEN(@PasswordHash) > 255
        THROW 50010, N'DATOS_INVALIDOS|Los datos del usuario son obligatorios y deben respetar sus longitudes.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Usuarios WHERE Username = @Username)
        THROW 50002, N'USUARIO_DUPLICADO|El nombre de usuario ya está registrado.', 1;

    INSERT INTO dbo.Usuarios (Username, NombreCompleto, PasswordHash)
    VALUES (@Username, @NombreCompleto, @PasswordHash);

    SELECT Id, Username, NombreCompleto, Activo, FechaCreacion
    FROM dbo.Usuarios WHERE Id = CONVERT(INT, SCOPE_IDENTITY());
END;
GO

/*
  Herramienta administrativa local para recuperar el acceso a una cuenta.
  La contraseña se genera y se convierte a Argon2id desde Python; nunca se
  envía en texto plano a SQL Server.
*/
CREATE OR ALTER PROCEDURE dbo.usp_Usuario_ActualizarPassword
    @Username NVARCHAR(50),
    @PasswordHash NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @Username = LTRIM(RTRIM(@Username));

    IF @Username IS NULL OR LEN(@Username) = 0 OR LEN(@Username) > 50
       OR @PasswordHash IS NULL OR LEN(@PasswordHash) = 0 OR LEN(@PasswordHash) > 255
        THROW 50010, N'DATOS_INVALIDOS|El usuario y el hash son obligatorios y deben respetar sus longitudes.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Usuarios
        WHERE Username = @Username
    )
        THROW 50001, N'USUARIO_NO_ENCONTRADO|El usuario no existe.', 1;

    UPDATE dbo.Usuarios
    SET PasswordHash = @PasswordHash
    WHERE Username = @Username;

    SELECT Id, Username, Activo
    FROM dbo.Usuarios
    WHERE Username = @Username;
END;
GO

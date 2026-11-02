/*
  El inicializador sustituye estos dos marcadores desde el .env local.
  La API recibe EXECUTE sobre dbo, sin permisos directos de tablas.
*/
DECLARE @Login SYSNAME = N'__DB_APP_USER__';
DECLARE @Password NVARCHAR(128) = N'__DB_APP_PASSWORD__';
DECLARE @Sql NVARCHAR(MAX);

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = @Login)
BEGIN
    SET @Sql = N'CREATE LOGIN ' + QUOTENAME(@Login) + N' WITH PASSWORD = N''' + REPLACE(@Password, N'''', N'''''') + N''', CHECK_POLICY = ON;';
    EXEC sys.sp_executesql @Sql;
END;
ELSE
BEGIN
    /* La inicialización sincroniza la contraseña con backend/.env para permitir una rotación controlada. */
    SET @Sql = N'ALTER LOGIN ' + QUOTENAME(@Login) + N' WITH PASSWORD = N''' + REPLACE(@Password, N'''', N'''''') + N''', CHECK_POLICY = ON;';
    EXEC sys.sp_executesql @Sql;
END;
GO

DECLARE @Login SYSNAME = N'__DB_APP_USER__';
DECLARE @Sql NVARCHAR(MAX);
IF DATABASE_PRINCIPAL_ID(@Login) IS NULL
BEGIN
    SET @Sql = N'CREATE USER ' + QUOTENAME(@Login) + N' FOR LOGIN ' + QUOTENAME(@Login) + N';';
    EXEC sys.sp_executesql @Sql;
END;
GO

DECLARE @Login SYSNAME = N'__DB_APP_USER__';
DECLARE @Sql NVARCHAR(MAX);
SET @Sql = N'GRANT EXECUTE ON SCHEMA::dbo TO ' + QUOTENAME(@Login) + N';'
    + N' DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO ' + QUOTENAME(@Login) + N';';
EXEC sys.sp_executesql @Sql;
GO

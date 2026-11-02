/* Base de datos de TecnoStock. Se ejecuta conectado a master. */
IF DB_ID(N'__DB_NAME_TEXT__') IS NULL
BEGIN
    CREATE DATABASE __DB_NAME__;
END;
GO

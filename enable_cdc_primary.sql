-- Enable CDC on the primary database
-- Replace 'YourDatabaseName' with your actual database name

USE master;
ALTER DATABASE [YourDatabaseName] SET RECOVERY FULL;
GO

USE [YourDatabaseName];
EXEC sys.sp_cdc_enable_db;
GO

-- To enable CDC on a specific table, uncomment and modify the following:
-- EXEC sys.sp_cdc_enable_table
--     @source_schema = N'dbo',
--     @source_name   = N'YourTableName',
--     @role_name     = NULL;
-- GO

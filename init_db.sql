-- This script creates the MyDatabase database and the TestData table, then inserts a test row.

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'MyDatabase')
BEGIN
    CREATE DATABASE [MyDatabase];
END
GO

USE [MyDatabase];
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'TestData')
BEGIN
    CREATE TABLE dbo.TestData (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Value NVARCHAR(100) NOT NULL,
        CreatedAt DATETIME2 DEFAULT GETDATE()
    );
    INSERT INTO dbo.TestData (Value) VALUES ('Initial test row');
END
GO

-- Create a simple table for testing data flow to replica
-- Replace 'MyDatabase' with your actual database name if needed

USE [MyDatabase];
GO

CREATE TABLE dbo.TestData (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Value NVARCHAR(100) NOT NULL,
    CreatedAt DATETIME2 DEFAULT GETDATE()
);
GO

-- Optionally, insert a test row
INSERT INTO dbo.TestData (Value) VALUES ('Initial test row');
GO

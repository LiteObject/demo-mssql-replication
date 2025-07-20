-- Setup the subscriber database
USE [master]
GO

-- Enable the database for subscription
USE [MyDatabase]
GO

-- Enable the database for subscription
EXEC sp_addsubscription 
    @publication = N'MyDatabasePublication', 
    @subscriber = @@SERVERNAME, 
    @destination_db = N'MyDatabase', 
    @subscription_type = N'Push', 
    @sync_type = N'automatic', 
    @article = N'all', 
    @update_mode = N'read only', 
    @subscriber_type = 0
GO

-- Start in master database for all replication setup
USE [master];
GO

-- Enable SQL Server Agent (required for replication)
IF '$(IS_PUBLISHER)' = 'true'
BEGIN
    EXEC sp_configure 'show advanced options', 1;
    RECONFIGURE;
    EXEC sp_configure 'Agent XPs', 1;
    RECONFIGURE;
END
GO

-- Setup distributor (must be in master)
IF '$(IS_PUBLISHER)' = 'true'
BEGIN
    -- Set up distributor
    IF NOT EXISTS (SELECT * FROM master.dbo.sysservers WHERE srvname = @@SERVERNAME AND srvid = 1)
    BEGIN
        EXEC sp_adddistributor @distributor = @@SERVERNAME, @password = N'DistPwd123!';
    END
    ELSE
    BEGIN
        PRINT 'Distributor already exists for server ' + @@SERVERNAME;
    END
    WAITFOR DELAY '00:00:05';
END
GO

-- Create distribution database (must be in master)
IF '$(IS_PUBLISHER)' = 'true'
BEGIN
    -- Create distribution database
    IF NOT EXISTS (SELECT * FROM master.dbo.sysdatabases WHERE name = N'distribution')
    BEGIN
        EXEC sp_adddistributiondb @database = N'distribution', 
            @data_folder = N'/var/opt/mssql/data', 
            @log_folder = N'/var/opt/mssql/data', 
            @log_file_size = 2, 
            @min_distretention = 0, 
            @max_distretention = 72, 
            @history_retention = 48;
    END
    ELSE
    BEGIN
        PRINT 'Distribution database already exists';
    END
    WAITFOR DELAY '00:00:10';
END
GO

-- Create MyDatabase if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'MyDatabase')
BEGIN
    CREATE DATABASE [MyDatabase];
END
GO

-- Switch to MyDatabase to create tables
USE [MyDatabase];
GO

-- Create TestData table if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TestData]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[TestData](
        [Id] [int] IDENTITY(1,1) PRIMARY KEY,
        [Value] [nvarchar](255) NULL,
        [CreatedAt] [datetime2](7) DEFAULT GETDATE() NULL
    );
END
GO

-- Create master key for distribution database (now that distribution DB exists)
IF '$(IS_PUBLISHER)' = 'true'
BEGIN
    -- Create master key for distribution database
    USE [distribution];
    IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    BEGIN
        CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'StrongMasterKeyPwd123!';
        PRINT 'Master key created for distribution database';
    END
    ELSE
    BEGIN
        PRINT 'Master key already exists for distribution database';
    END

    -- Add distributor publisher (required for replication to work)
    EXEC sp_adddistpublisher @publisher = N'MSSQL_TEST', @distribution_db = N'distribution', @security_mode = 1;

    -- Switch back to master when done
    USE [master];
END
GO

-- Create the replication directory (required for replication agents)
IF '$(IS_PUBLISHER)' = 'true'
BEGIN
    -- The replication directory is created at the OS level
    -- This is handled by the Docker container setup
    PRINT 'Replication directory should be created at /var/opt/mssql/ReplData';
END
GO

IF '$(IS_PUBLISHER)' = 'true'
BEGIN
    -- Enable publication on MyDatabase
    USE [MyDatabase];
    EXEC sp_replicationdboption 
        @dbname = N'MyDatabase', 
        @optname = N'publish', 
        @value = N'true';
END
GO

IF '$(IS_PUBLISHER)' = 'true'
BEGIN
    -- Create publication
    IF NOT EXISTS (SELECT * FROM syspublications WHERE name = N'MyPublication')
    BEGIN
        EXEC sp_addpublication 
            @publication = N'MyPublication', 
            @description = N'Transactional publication of database ''MyDatabase''',
            @sync_method = N'concurrent', 
            @retention = 0, 
            @allow_push = N'true', 
            @allow_pull = N'true', 
            @allow_anonymous = N'false', 
            @enabled_for_internet = N'false', 
            @snapshot_in_defaultfolder = N'true', 
            @compress_snapshot = N'false', 
            @ftp_port = 21, 
            @ftp_login = N'anonymous', 
            @allow_subscription_copy = N'false', 
            @add_to_active_directory = N'false', 
            @repl_freq = N'continuous', 
            @status = N'active', 
            @independent_agent = N'true', 
            @immediate_sync = N'true', 
            @allow_sync_tran = N'false', 
            @autogen_sync_procs = N'false', 
            @allow_queued_tran = N'false', 
            @allow_dts = N'false', 
            @replicate_ddl = 1;
    END
END
GO

IF '$(IS_PUBLISHER)' = 'true'
BEGIN
    -- Add article
    IF NOT EXISTS (SELECT * FROM sysarticles WHERE name = N'TestData')
    BEGIN
        EXEC sp_addarticle 
            @publication = N'MyPublication', 
            @article = N'TestData', 
            @source_owner = N'dbo', 
            @source_object = N'TestData', 
            @type = N'logbased', 
            @description = NULL, 
            @creation_script = NULL, 
            @pre_creation_cmd = N'drop', 
            @schema_option = 0x000000000803509F, 
            @identityrangemanagementoption = N'manual', 
            @destination_table = N'TestData', 
            @destination_owner = N'dbo', 
            @vertical_partition = N'false';
    END
END
GO

IF '$(IS_PUBLISHER)' = 'true'
BEGIN
    -- Create snapshot agent job
    EXEC sp_addpublication_snapshot 
        @publication = N'MyPublication', 
        @frequency_type = 1, 
        @frequency_interval = 0, 
        @frequency_relative_interval = 0, 
        @frequency_recurrence_factor = 0, 
        @frequency_subday = 0, 
        @frequency_subday_interval = 0, 
        @active_start_time_of_day = 0, 
        @active_end_time_of_day = 235959, 
        @active_start_date = 0, 
        @active_end_date = 0, 
        @job_login = NULL, 
        @job_password = NULL, 
        @publisher_security_mode = 1;
END
GO

IF '$(IS_PUBLISHER)' = 'true'
BEGIN
    -- Add linked server to subscriber
    IF NOT EXISTS (SELECT * FROM sys.servers WHERE name = 'mssql_replica')
    BEGIN
        EXEC sp_addlinkedserver 
            @server = N'mssql_replica', 
            @srvproduct = N'SQL Server';
        
        EXEC sp_addlinkedsrvlogin 
            @rmtsrvname = N'mssql_replica', 
            @useself = N'FALSE', 
            @locallogin = NULL, 
            @rmtuser = N'sa', 
            @rmtpassword = N'YourStrong!Passw0rd';
    END
END
GO

IF '$(IS_PUBLISHER)' = 'true'
BEGIN
    -- Add subscription (with retry logic for subscriber readiness)
    IF OBJECT_ID('sp_addsubscription') IS NOT NULL
    BEGIN
        -- Wait for subscriber to be ready
        DECLARE @retry_count INT = 0;
        DECLARE @max_retries INT = 60;  -- Increased retry count
        DECLARE @subscriber_ready BIT = 0;
        
        WHILE @retry_count < @max_retries AND @subscriber_ready = 0
        BEGIN
            BEGIN TRY
                -- Test connection to subscriber and check if database exists
                EXEC sp_testlinkedserver N'mssql_replica';
                
                -- Also check if the database exists on the subscriber
                DECLARE @sql NVARCHAR(MAX) = N'SELECT 1 FROM [mssql_replica].[MyDatabase].[sys].[databases] WHERE name = ''MyDatabase''';
                EXEC sp_executesql @sql;
                
                SET @subscriber_ready = 1;
                PRINT 'Subscriber is ready for replication setup';
            END TRY
            BEGIN CATCH
                SET @retry_count = @retry_count + 1;
                PRINT 'Waiting for subscriber to be ready... Attempt ' + CAST(@retry_count AS VARCHAR(10)) + '/' + CAST(@max_retries AS VARCHAR(10));
                WAITFOR DELAY '00:00:05';  -- Wait 5 seconds between retries
            END CATCH
        END
        
        IF @subscriber_ready = 1
        BEGIN
            EXEC sp_addsubscription 
                @publication = N'MyPublication', 
                @subscriber = N'mssql_replica', 
                @destination_db = N'MyDatabase', 
                @subscription_type = N'Push', 
                @sync_type = N'automatic', 
                @article = N'all', 
                @update_mode = N'read only', 
                @subscriber_type = 0;
            
            EXEC sp_addpushsubscription_agent 
                @publication = N'MyPublication', 
                @subscriber = N'mssql_replica', 
                @subscriber_db = N'MyDatabase', 
                @job_login = NULL, 
                @job_password = NULL, 
                @subscriber_security_mode = 0, 
                @subscriber_login = N'sa', 
                @subscriber_password = N'YourStrong!Passw0rd', 
                @frequency_type = 64, 
                @frequency_interval = 0, 
                @frequency_relative_interval = 0, 
                @frequency_recurrence_factor = 0, 
                @frequency_subday = 0, 
                @frequency_subday_interval = 0, 
                @active_start_time_of_day = 0, 
                @active_end_time_of_day = 235959, 
                @active_start_date = 0, 
                @active_end_date = 99991231, 
                @dts_package_location = N'Distributor';
            
            PRINT 'Subscription and push subscription agent created successfully';
            
            PRINT 'DEBUG: About to start automatic snapshot agent job startup logic...';
            
            -- NOW start the snapshot agent job that was just created
            PRINT 'Starting automatic snapshot agent job after subscription creation...';
            
            -- Wait longer for job system to create the job after sp_addpushsubscription_agent
            WAITFOR DELAY '00:00:30';
            
            DECLARE @snap_job_name sysname = NULL;
            DECLARE @snap_attempts INT = 0;
            DECLARE @snap_max_attempts INT = 10;
            DECLARE @snap_job_started BIT = 0;
            
            -- Try to find and start the snapshot agent job
            WHILE @snap_attempts < @snap_max_attempts AND @snap_job_started = 0
            BEGIN
                SET @snap_job_name = NULL;
                
                -- Look for the most recent snapshot agent job
                SELECT TOP 1 @snap_job_name = name
                FROM msdb.dbo.sysjobs 
                WHERE category_id = 15 -- Snapshot Agent category
                ORDER BY date_created DESC;
                
                IF @snap_job_name IS NOT NULL
                BEGIN
                    PRINT 'Found snapshot agent job: ' + @snap_job_name;
                    
                    -- Check if job has execution history
                    DECLARE @snap_job_history_count INT;
                    SELECT @snap_job_history_count = COUNT(*)
                    FROM msdb.dbo.sysjobhistory jh
                    INNER JOIN msdb.dbo.sysjobs j ON jh.job_id = j.job_id
                    WHERE j.name = @snap_job_name;
                    
                    IF @snap_job_history_count = 0
                    BEGIN
                        PRINT 'Job has no execution history. Starting job...';
                        BEGIN TRY
                            EXEC msdb.dbo.sp_start_job @job_name = @snap_job_name;
                            PRINT 'SUCCESS: Snapshot agent job started automatically after subscription creation!';
                            SET @snap_job_started = 1;
                        END TRY
                        BEGIN CATCH
                            PRINT 'Error starting job: ' + ERROR_MESSAGE();
                            SET @snap_attempts = @snap_attempts + 1;
                            WAITFOR DELAY '00:00:03';
                        END CATCH
                    END
                    ELSE
                    BEGIN
                        PRINT 'Job already has execution history - no need to start.';
                        SET @snap_job_started = 1;
                    END
                END
                ELSE
                BEGIN
                    SET @snap_attempts = @snap_attempts + 1;
                    PRINT 'Snapshot job not found yet, waiting... (attempt ' + CAST(@snap_attempts AS VARCHAR) + ')';
                    WAITFOR DELAY '00:00:03';
                END
            END
            
            IF @snap_job_started = 1
            BEGIN
                PRINT 'Automatic snapshot agent job startup completed successfully!';
            END
            ELSE
            BEGIN
                PRINT 'WARNING: Could not find or start snapshot agent job after subscription creation.';
            END
        END
        ELSE
        BEGIN
            PRINT 'WARNING: Subscriber not ready after ' + CAST(@max_retries AS VARCHAR(10)) + ' attempts. Replication setup may be incomplete.';
        END
    END
END
GO

-- Remove the old timing-based automatic startup logic as it's now moved to after subscription creation
GO
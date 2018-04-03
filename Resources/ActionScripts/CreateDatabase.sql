



BEGIN
	DECLARE  
		@DbName VARCHAR(400) = N'$(dbName)',
		@ServerName varchar(100) = (SELECT CAST(SERVERPROPERTY('ServerName') as Varchar)),
		@InstanceName varchar(100) = (SELECT CAST(SERVERPROPERTY('InstanceName') as Varchar)),
		@UI varchar(100),
		@Qry VARCHAR(MAX) 

		
		----Create Needed SQLRUsergroup Name , 
		----if Default Instance UI = {ServerName}\SQLRUserGroup 
		----if Named Instance {ServerName}\SQLRUserGroup{InstanceName} 
		
		-- If @InstanceName is null 
		-- 	BEGIN 
		-- 		SET @UI = @ServerName + '\SQLRUserGroup' 
		-- 	END 

		-- If @InstanceName is Not null 
		-- 	BEGIN 
		-- 		SET @UI = @ServerName + '\SQLRUserGroup' + @InstanceName
		-- 	END 

		declare @login_name nvarchar(500) = CONCAT(CAST(SERVERPROPERTY('MachineName') as nvarchar(128)), '\SQLRUserGroup',
                                      CAST(SERVERPROPERTY('InstanceName') as nvarchar(128)));
		if SUSER_ID(@login_name) is null
		begin
      	 set @login_name = QUOTENAME(@login_name);
       	exec('create login ' + @login_name + ' from windows;');
		end;




	SET @Qry = 
		(' 
		EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N''<DBName>''
		USE [master]
		ALTER DATABASE <DBName> SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
		USE [master]
		DROP DATABASE <DBName>
		')


	--If DB Already Exists , Drop it and recreate it 
	IF EXISTS(select * from sys.databases where name = @DbName)
	
	BEGIN 
		SET @Qry = (REPLACE(@Qry,'<dbName>',@DbName) )
		EXEC (@Qry) 
	END 

	
	DECLARE @Query VARCHAR(MAX)=''
---Find Default Database File Path and Create DB there 
	DECLARE @DbFilePath VARCHAR(400) = (SELECT top 1 LEFT(physical_name, (LEN(physical_name) - CHARINDEX('\',REVERSE(physical_name)))) + '\' as BasePath FROM sys.master_files WHERE type_desc = 'ROWS')

--Find Default Log File Path and Create Log there
	DECLARE @LogFilePath VARCHAR(400) = (SELECT top 1 LEFT(physical_name, (LEN(physical_name) - CHARINDEX('\',REVERSE(physical_name)))) + '\' as BasePath FROM sys.master_files WHERE type_desc = 'LOG')


	IF NOT EXISTS(select * from sys.databases where name = @DbName)
	BEGIN
		SET @Query = @Query + 'CREATE DATABASE '+@DbName +' ON  PRIMARY '
		SET @Query = @Query + '( NAME = '''+@DbName +''', FILENAME = '''+@DbFilePath+@DbName +'.mdf'' , SIZE = 73728KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB ) '
		SET @Query = @Query + ' LOG ON '
		SET @Query = @Query + '( NAME = '''+@DbName +'_log'', FILENAME = '''+@LogFilePath+@DbName +'_log.ldf'' , SIZE = 1024KB , MAXSIZE = 2048GB , FILEGROWTH = 1024KB)'
		exec(@query)
	END


	----CREATE USER SQLRUserGroup on SQL Server

	SET @Qry = 
	'
	IF NOT EXISTS (SELECT name FROM master.sys.server_principals where name = ''<ui>'')
	BEGIN CREATE LOGIN [<ui>] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english] END
	'
	SET @Qry = REPLACE(@qry,'<ui>', @ui)
	
	EXEC (@Qry)
	--SELECT @Qry


	--Give SQLRUserGroup Rights To Database(s)
	SET @Qry = 
	'
	USE [<dbName>]
	CREATE USER [<ui>] FOR LOGIN [<ui>]

	ALTER USER [<ui>] WITH DEFAULT_SCHEMA=NULL

	ALTER AUTHORIZATION ON SCHEMA::[db_datareader] TO [<ui>]

	ALTER AUTHORIZATION ON SCHEMA::[db_datawriter] TO [<ui>]

	ALTER AUTHORIZATION ON SCHEMA::[db_ddladmin] TO [<ui>]
	
	ALTER ROLE [db_datareader] ADD MEMBER [<ui>]

	ALTER ROLE [db_datawriter] ADD MEMBER [<ui>]

	ALTER ROLE [db_ddladmin] ADD MEMBER [<ui>]
	'
	SET @Qry = REPLACE(REPLACE(@qry,'<ui>', @ui),'<dbName>',@DbName) 
	
	EXEC (@Qry)
	--SELECT @Qry

END 

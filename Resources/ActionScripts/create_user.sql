-- This script enables mixed authentication on SQL Server, creates a user 'rdemo' with password 'D@tascience2016' and gives them the orrec permissions

-- Pre-requisites: 
-- 1) You should connect to the database in the SQL Server of the DSVM with:
-- Server Name: localhost
-- Integrated authentication is used

DECLARE @User varchar(50);
DECLARE @Password varchar(50);

-- Set default username and password. Change these values to use different username and password
SET @User = 'rdemo'
SET @Password = 'D@atascience2016'

EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2
DECLARE @sqlstmt varchar(200)
SET @sqlstmt = 'CREATE LOGIN ' + @User + ' WITH PASSWORD='''+@Password+''', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF'
EXEC (@sqlstmt)
SET @sqlstmt = 'ALTER SERVER ROLE [sysadmin] ADD MEMBER '+@User
EXEC(@sqlstmt)
EXEC sp_configure 'external scripts enabled', 1
RECONFIGURE WITH OVERRIDE
GO
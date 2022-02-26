--exec sp_MSforeachDB 'print "n o w l o o k i n g a t ? " ;exec dba.dbo.DBAfileSpaceUsage ?'
----run in Text results
----then in results window if you do a Find and BOOKMARK all – then those lines will be
----highlighted    like so  ( find G:\ )
---- For every DB on a certain drive where space exists
--exec msdb. dbo.sp_msforeachDB 'use [?] select
--       [FileSizeMB]  =
--              convert(numeric (10, 2),round (a. size/128. ,2)),
--       [UsedSpaceMB] =
--              convert(numeric (10, 2),round (fileproperty( a.name ,''SpaceUsed'')/ 128.,2 )) ,
--       [UnusedSpaceMB]      =
--              convert(numeric (10, 2),round ((a. size-fileproperty ( a.name ,''SpaceUsed''))/ 128.,2 )) ,
--       GrowthPct     =
--              case when a. is_percent_growth = 1 then a .growth else null end,
--       GrowthMB      =
--              convert(int ,round( case when a. is_percent_growth = 1 then null else a. growth / 128.000 end, 0)),
--       [DBFileName]  = a. name,
--      physical_name  ,
--              getdate (),
--              ''DBCC SHRINKFILE ('''''' + a.name + '''''', 0)''
--from
--       sys .database_files a
--where physical_name  like ''G:\%''
--and convert(numeric (10, 2),round ((a. size-fileproperty ( a.name ,''SpaceUsed''))/ 128.,2 )) > 100'
-- Shrink_DB_File.sql
/*
This script is used to shrink a database file in
increments until it reaches a target free space limit.
Run this script in the database with the file to be shrunk.
1. Set @DBFileName to the name of database file to shrink.
2. Set @TargetFreeMB to the desired file free space in MB after shrink.
3. Set @ShrinkIncrementMB to the increment to shrink file by in MB
4. Run the script
BE CAREFUL THIS DOESN'T GET STUCK IN A LOOP IF SHRINK CANNOT OCCUR
*/
declare @DBFileName sysname
declare @TargetFreeMB int
declare @ShrinkIncrementMB int
declare @databaseName sysname
declare @starttime DATETIME
SET NOCOUNT ON
--     Set name of Database
set @databaseName = 'OLAP_DATA'
--     Set Name of Database file to shrink
set @DBFileName = 'OLAP_Data'
--     Set Desired file free space in MB after shrink
set @TargetFreeMB = 100
--     Set Increment to shrink file by in MB
set @ShrinkIncrementMB = 512
-- Show Size, Space Used, Unused Space, and Name of all database files
select
       [FileSizeMB]  =
              convert(numeric (10, 2),round (a. size/128. ,2)),
       [UsedSpaceMB] =
              convert(numeric (10, 2),round (fileproperty( a.name ,'SpaceUsed')/ 128.,2 )) ,
       [UnusedSpaceMB]      =
              convert(numeric (10, 2),round ((a. size-fileproperty ( a.name ,'SpaceUsed'))/ 128.,2 )) ,
       [DBLogicalName]  = a. name,
       [DBFileName] = a.filename
from
       sysfiles a
       order by 3 desc
declare @sql varchar( 8000)
declare @SizeMB int
declare @UsedMB int
-- Get current file size in MB
select @SizeMB = size/128. from sysfiles where name = @DBFileName
-- Get current space used in MB
select @UsedMB = fileproperty( @DBFileName,'SpaceUsed' )/128.
select [StartFileSize] = @SizeMB, [StartUsedSpace] = @UsedMB, [DBFileName] = @DBFileName
-- Loop until file at desired size
while  @SizeMB > @UsedMB+@TargetFreeMB +@ShrinkIncrementMB
       begin
       set @sql =
             'dbcc shrinkfile ( N''' +@DBFileName + ''', '+
       convert(varchar (20), @SizeMB-@ShrinkIncrementMB )+' ) '
       print 'Start ' + @sql
       print 'at ' +convert( varchar(30 ),getdate(), 121)
             SET @starttime = getdate()
       exec ( @sql )
             print 'Done ' + @sql
             -- Get current file size in MB
       select @SizeMB = size/128. from sysfiles where name = @DBFileName
 
       -- Get current space used in MB
       select @UsedMB = fileproperty( @DBFileName,'SpaceUsed' )/128.
             DECLARE @IncreaseBy1MB INT
             SET @IncreaseBy1MB = @SizeMB + 1
             SET @SQL = 'ALTER DATABASE ['+@databaseName+'] MODIFY FILE ( NAME = N''' + @DBFileName + ''', SIZE = ' + CAST(@IncreaseBy1MB AS VARCHAR) + 'MB)'
             exec (@SQL)
             print 'Done ' + @sql
       print 'at ' +convert( varchar(30 ),getdate(), 121)
             print 'Time Taken in seconds: ' + CAST(DATEDIFF(s,@starttime, getdate()) as VARCHAR)
       select [FileSize] = @SizeMB, [UsedSpace] = @UsedMB, [DBFileName] = @DBFileName
       end
select [EndFileSize] = @SizeMB, [EndUsedSpace] = @UsedMB, [DBFileName] = @DBFileName
-- Show Size, Space Used, Unused Space, and Name of all database files
select
       [FileSizeMB]  =
              convert(numeric (10, 2),round (a. size/128. ,2)),
       [UsedSpaceMB] =
              convert(numeric (10, 2),round (fileproperty( a.name ,'SpaceUsed')/ 128.,2 )) ,
       [UnusedSpaceMB]      =
              convert(numeric (10, 2),round ((a. size-fileproperty ( a.name ,'SpaceUsed'))/ 128.,2 )) ,
       [DBLogicalName]  = a. name,
       [DBFileName] = a.filename
from
       sysfiles a
       order by 3 desc
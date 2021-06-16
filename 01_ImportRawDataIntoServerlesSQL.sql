
-- There was no point in downloading data simply to upload it again for this task
-- Instead we created our required tables as external tables by reading in the data from
-- Azure open data sets

-- This script should connect to the Built-in SQL Pool

-- Find out what the table contains
EXEC sp_describe_first_result_set N'
SELECT
    TOP 1000 * 
FROM
    OPENROWSET(
        BULK ''https://azureopendatastorage.blob.core.windows.net/nyctlc/yellow/puYear=*/puMonth=*/*.parquet'',
        FORMAT = ''parquet''
    ) AS [result]'

-- Check your selection perform a rudimentary data clean
SELECT
    TOP 1000 tpepPickupDateTime, tpepDropOffDateTime, tripDistance, puLocationId, doLocationId 
FROM
    OPENROWSET(
        BULK 'https://azureopendatastorage.blob.core.windows.net/nyctlc/yellow/puYear=*/puMonth=*/*.parquet',
        FORMAT = 'parquet'
    ) AS [result]
WHERE tpepPickupDateTime IS NOT NULL
 AND tpepDropOffDateTime IS NOT NULL
 AND puLocationID IS NOT NULL    
 AND doLocationID IS NOT NULL
 AND tripDistance > 0

-- Once happy with the results
-- Create a location for your data and point your data source there
CREATE EXTERNAL DATA SOURCE taxiDataDemo WITH (
    LOCATION = 'https://dnmay25gen2.blob.core.windows.net/dnmay25users/user'
);

-- Create a serverless database - This data set is in UTF8 format
USE master;  
GO  
ALTER DATABASE nyctaxiDB  
COLLATE Latin1_General_100_CI_AI_SC_UTF8 ;  
GO  
  
--Verify the collation setting.  
SELECT name, collation_name  
FROM sys.databases  
WHERE name = N'nyctaxiDB';  
GO  

use nyctaxiDB

--Create a parquet file format for out data
CREATE EXTERNAL FILE FORMAT taxiData_file_format
WITH
(  
    FORMAT_TYPE = PARQUET,
    DATA_COMPRESSION = 'org.apache.hadoop.io.compress.SnappyCodec'
);

-- Create the raw data external table (limit to 2018 while testing)
-- I use the CETAS method - This stores the data in the table but requires you delete the parquet files 
-- if you want to drop the table completely

CREATE EXTERNAL TABLE RawTripData (
    tpepPickupDateTime DateTime, 
    tpepDropOffDateTime DateTime, 
    tripDistance Float, 
    puLocationId varchar(100), 
    doLocationId varchar(100)
)
WITH (
    LOCATION = 'raw_data/',
    DATA_SOURCE = taxiDataDemo,  
    FILE_FORMAT = taxiData_file_format
)  
AS
SELECT
    tpepPickupDateTime, tpepDropOffDateTime, tripDistance, puLocationId, doLocationId 
FROM
    OPENROWSET(
        BULK 'https://azureopendatastorage.blob.core.windows.net/nyctlc/yellow/puYear=*/puMonth=*/*.parquet',
        FORMAT = 'parquet'
    ) AS [result]
WHERE tpepPickupDateTime IS NOT NULL
 AND tpepDropOffDateTime IS NOT NULL
 AND puLocationID IS NOT NULL    
 AND doLocationID IS NOT NULL
 AND tripDistance > 0

--See what we have
select count(*) from RawTripData

-- Create the Zone Distances external table using trip data

CREATE EXTERNAL TABLE [dbo].[ZoneDistances]
WITH (
    LOCATION = 'agg_data/',
    DATA_SOURCE = taxiDataDemo,  
    FILE_FORMAT = taxiData_file_format
)  
AS
SELECT
    1000000 + (IIF(ISNUMERIC(puLocationId) = 1, CAST(puLocationId AS INT), 0) * 1000) + (IIF(ISNUMERIC(doLocationId) = 1, CAST(doLocationId AS INT), 0)) AS TripIndex, 
    puLocationId as puLocationId,
    doLocationId as doLocationId,
    AVG(tripDistance) as AvgTripDistance
FROM
    RawTripData
Group By    
    puLocationId, doLocationId

Select count(*) from ZoneDistances 


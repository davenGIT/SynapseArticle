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
        BULK     ''https://azureopendatastorage.blob.core.windows.net/nyctlc/yellow/puYear=*/puMonth=*/*.parquet'',
        FORMAT = ''parquet''
    ) AS [result]'

-- Check your selection perform a rudimentary data clean
SELECT
    TOP 1000 tpepPickupDateTime, tpepDropOffDateTime, tripDistance, puLocationId, doLocationId 
FROM
    OPENROWSET(
        BULK     'https://azureopendatastorage.blob.core.windows.net/nyctlc/yellow/puYear=*/puMonth=*/*.parquet',
        FORMAT = 'parquet'
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
-- I use the CETAS method - This stores the data in the table
CREATE EXTERNAL TABLE trips
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
        BULK     'https://azureopendatastorage.blob.core.windows.net/nyctlc/yellow/puYear=2018/puMonth=*/*.parquet',
        FORMAT = 'parquet'
    ) AS [result]
WHERE tpepPickupDateTime IS NOT NULL
 AND tpepDropOffDateTime IS NOT NULL
 AND puLocationID IS NOT NULL    
 AND doLocationID IS NOT NULL
 AND tripDistance > 0

--See what we have
select count(*) from trips

-- Create the aggregated data external table using our imported data
CREATE EXTERNAL TABLE tripDistanceTable
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
    trips
Group By    
    puLocationId, doLocationId

Select top 10 * from tripDistanceTable

-- Create the aggregated demand external table 
CREATE EXTERNAL TABLE demandSummary
WITH (
    LOCATION = 'agg_demand/',
    DATA_SOURCE = taxiDataDemo,  
    FILE_FORMAT = taxiData_file_format
)  
AS
SELECT
    td.TripIndex as TripIndex, 
    DATEPART(year, tpepPickupDateTime) as puYear, 
    DATEPART(month, tpepPickupDateTime) as puMonth, 
    DATEPART(day, tpepPickupDateTime) as puday, 
    DATEPART(hour, tpepPickupDateTime) as puhour, 
    count(tripDistance) as trips
FROM
    trips t
    INNER JOIN tripDistanceTable td ON t.puLocationId = td.puLocationId AND t.doLocationId = td.doLocationId
where tripDistance > 0    
Group By    
    td.TripIndex, 
    DATEPART(year, tpepPickupDateTime), 
    DATEPART(month, tpepPickupDateTime), 
    DATEPART(day, tpepPickupDateTime), 
    DATEPART(hour, tpepPickupDateTime) 

SELECT top 10 * from demandSummary


-- Create the aggregated supply external table 
CREATE EXTERNAL TABLE supplySummary
WITH (
    LOCATION = 'agg_supply/',
    DATA_SOURCE = taxiDataDemo,  
    FILE_FORMAT = taxiData_file_format
)  
AS
SELECT
    t.doLocationId as TripIndex, 
    DATEPART(year, tpepDropOffDateTime) as puYear, 
    DATEPART(month, tpepDropOffDateTime) as puMonth, 
    DATEPART(day, tpepDropOffDateTime) as puday, 
    DATEPART(hour, tpepDropOffDateTime) as puhour, 
    count(tripDistance) as trips
FROM
    trips t
where tripDistance > 0    
Group By    
    t.doLocationId, 
    DATEPART(year, tpepDropOffDateTime), 
    DATEPART(month, tpepDropOffDateTime), 
    DATEPART(day, tpepDropOffDateTime), 
    DATEPART(hour, tpepDropOffDateTime) 


SELECT top 10 * from supplySummary
 
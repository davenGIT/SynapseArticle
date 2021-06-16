
-- Create the aggregated demand external table Zone level

--DROP EXTERNAL TABLE HourlyZoneDemand
--DROP EXTERNAL TABLE supplySummary
--DROP EXTERNAL TABLE HourlyOverSupply
--DROP EXTERNAL TABLE HourlyUnderSupply

-- Don't forget to also delete the location directory from the  

CREATE EXTERNAL TABLE HourlyZoneDemand
WITH (
    LOCATION = 'agg_zonedemand/',
    DATA_SOURCE = taxiDataDemo,  
    FILE_FORMAT = taxiData_file_format
)  
AS
SELECT * from dbo.vHourlyZoneDemand


-- Create the aggregated supply external table 
CREATE EXTERNAL TABLE supplySummary
WITH (
    LOCATION = 'agg_supply/',
    DATA_SOURCE = taxiDataDemo,  
    FILE_FORMAT = taxiData_file_format
)  
AS
SELECT * from vHourlySupply

-- Create the zone over supply for deployment 
CREATE EXTERNAL TABLE HourlyOverSupply
WITH (
    LOCATION = 'agg_overSupply/',
    DATA_SOURCE = taxiDataDemo,  
    FILE_FORMAT = taxiData_file_format
)  
AS
SELECT * from vHourlyOverSupply

-- Create the zone under supply for deployment 
CREATE EXTERNAL TABLE HourlyUnderSupply
WITH (
    LOCATION = 'agg_underSupply/',
    DATA_SOURCE = taxiDataDemo,  
    FILE_FORMAT = taxiData_file_format
)  
AS
SELECT * from vHourlyUnderSupply



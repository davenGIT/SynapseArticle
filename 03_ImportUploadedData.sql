use nyctaxiDB

--Create aparquet file format
CREATE EXTERNAL FILE FORMAT taxiData_file_format_GZIP
WITH
(  
    FORMAT_TYPE = PARQUET,
    DATA_COMPRESSION = 'org.apache.hadoop.io.compress.GzipCodec'
);

-- Create the aggregated data external table (limit to 2018 while testing)
CREATE EXTERNAL TABLE tripDistanceUploaded
(
    TripIndex INT,
    PULocationID INT,
    DOLocationID INT,
    AverageTrip FLOAT
)
WITH (
    LOCATION = 'uploadedData/',
    DATA_SOURCE = taxiDataDemo,  
    FILE_FORMAT = taxiData_file_format_GZIP
)  

--DROP EXTERNAL TABLE tripDistanceUploaded

--Select * from tripDistanceUploaded


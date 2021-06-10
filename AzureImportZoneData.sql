-- The trip data contains only the zone ID but each zone is within a borough.
-- The borough information was downloaded in CSV format from
-- https://storage.googleapis.com/kagglesdsdata/datasets/1062312/1793773/taxi_zone_lookup.csv?X-Goog-Algorithm=GOOG4-RSA-SHA256&X-Goog-Credential=gcp-kaggle-com%40kaggle-161607.iam.gserviceaccount.com%2F20210610%2Fauto%2Fstorage%2Fgoog4_request&X-Goog-Date=20210610T073216Z&X-Goog-Expires=259199&X-Goog-SignedHeaders=host&X-Goog-Signature=2f8ad15ad4ee61316b33702d1623561f361ec4cc5e1415453c48af86549d0320a0f79bc42d3fd0c58bf1902172bdcb57b166ca90153fb360ab000772936e7af58f36af3ea833d6d91bcfa3ff6eb967b4cf2a543fd2c854cac1c2aec73ba61d6f69c16de4dd07fbf6239f6bca974a788f05c6769cb4be8d4f3398ba484586da7456782fdec6d4063e92ec050ead4ac1489ea245c79b192abc41773b21c7f41ec1ac79a3906be5e07648887eac4df4c6005f56cb42d5beeccfdb1fcc0700f809e03985c8bf784b3ac5a37846f3b6da5abf7d130a8316198f2c08793915ced6aad5d60e5444db802c0ac912eca137515804bbdc30f6d37953616a7d7de0a528f5da

-- Not sure why I did this with GZIP compression when everything else is using the snappy codec 

use nyctaxiDB

--Create aparquet file format
CREATE EXTERNAL FILE FORMAT taxiData_file_format_GZIP
WITH
(  
    FORMAT_TYPE = PARQUET,
    DATA_COMPRESSION = 'org.apache.hadoop.io.compress.GzipCodec'
);

-- Create the aggregated data external table (limit to 2018 while testing)
CREATE EXTERNAL TABLE zoneLookup
(
    LocationID INT,
    Borough VARCHAR(100),
    Zone VARCHAR(100),
    service_zone VARCHAR(100)
)
WITH (
    LOCATION = 'zoneLookup/',
    DATA_SOURCE = taxiDataDemo,  
    FILE_FORMAT = taxiData_file_format_GZIP
)  

--DROP EXTERNAL TABLE tripDistanceUploaded

Select * from zoneLookup

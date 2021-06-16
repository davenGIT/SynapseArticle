----------------  vHourlyFcstDemand  ------------------------------------------------------

IF EXISTS(select * FROM sys.views where name = 'vHourlyFcstDemand')
DROP VIEW [dbo].[vHourlyFcstDemand]
GO

CREATE VIEW [dbo].[vHourlyFcstDemand]
AS
SELECT      DATEPART(Year, t.tpepPickupDateTime) * 1000000 + DATEPART(month, t.tpepPickupDateTime) * 10000 + 
                         DATEPART(day, t.tpepPickupDateTime) * 100 + DATEPART(hour, t.tpepPickupDateTime) as PUFcstPeriod,
		    DATEPART(Year, t.tpepDropOffDateTime) * 1000000 + DATEPART(month, t.tpepDropOffDateTime) * 10000 + 
                         DATEPART(day, t.tpepDropOffDateTime) * 100 + DATEPART(hour, t.tpepDropOffDateTime) as DOFcstPeriod,
 			max(CAST(t.puLocationId AS INT)) as PUFcstZone, 
			max(CAST(t.doLocationID as INT)) as DOFcstZone, 
			max(DATETIMEFROMPARTS ( 
				DATEPART(Year, t.tpepPickupDateTime), 
				DATEPART(month, t.tpepPickupDateTime), 
				DATEPART(day, t.tpepPickupDateTime), 
				DATEPART(hour, t.tpepPickupDateTime), 
				0, 
				0, 
				0
			)) as PUFcstPeriodDate,
			max(DATETIMEFROMPARTS ( 
				DATEPART(Year, t.tpepDropOffDateTime), 
				DATEPART(month, t.tpepDropOffDateTime), 
				DATEPART(day, t.tpepDropOffDateTime), 
				DATEPART(hour, t.tpepDropOffDateTime), 
				0, 
				0, 
				0
			)) as DOFcstPeriodDate,
			max(DATEPART(Year, t.tpepPickupDateTime)) as PUYear, 
			max(DATEPART(month, t.tpepPickupDateTime)) as PUMonth, 
			max(DATEPART(day, t.tpepPickupDateTime)) as PUDay, 
			max(DATEPART(hour, t.tpepPickupDateTime)) as PUHour, 
			zd.TripIndex as TripIndex, 
			Count(t.tpepPickupDateTime) as demand
FROM        dbo.RawTripData t 
INNER JOIN  dbo.ZoneDistances zd ON t.puLocationID = zd.PULocationID AND t.DOLocationID = zd.DOLocationID
WHERE		t.tpepPickupDateTime BETWEEN '1 JAN 2017' AND '30 JUN 2019'
GROUP BY	
           DATEPART(Year, t.tpepPickupDateTime) * 1000000 + DATEPART(month, t.tpepPickupDateTime) * 10000 + 
                         DATEPART(day, t.tpepPickupDateTime) * 100 + DATEPART(hour, t.tpepPickupDateTime),
		   DATEPART(Year, t.tpepDropOffDateTime) * 1000000 + DATEPART(month, t.tpepDropOffDateTime) * 10000 + 
                         DATEPART(day, t.tpepDropOffDateTime) * 100 + DATEPART(hour, t.tpepDropOffDateTime),
			zd.TripIndex

GO

-----------------  vZoneLookup  ------------------------------------------------------

IF EXISTS(select * FROM sys.views where name = 'vZoneLookup')
DROP VIEW [dbo].[vZoneLookup]
GO

CREATE VIEW [dbo].[vZoneLookup]
AS
	Select
		rzk.LocationID,
		bl.idx as BoroughID
	from RawZoneLookup rzk
	INNER JOIN vBoroughLookup bl ON bl.Borough = rzk.Borough
GO

----------------  vHourlyZoneDemand  ------------------------------------------------------

IF EXISTS(select * FROM sys.views where name = 'vHourlyZoneDemand')
DROP VIEW [dbo].[vHourlyZoneDemand]
GO

CREATE VIEW [dbo].[vHourlyZoneDemand]
AS
SELECT      hfd.PUFcstPeriod as FcstPeriod,
 			hfd.PUFcstZone as FcstZone, 
			hfd.TripIndex as TripIndex, 
			max(hfd.PUFcstPeriodDate) as FcstPeriodDate,
			max(hfd.PUYear) as FcstYear,
			max(hfd.PUMonth) as FcstMonth,
			max(hfd.PUDay) as FcstDay,
			max(hfd.PUHour) as FcstHour,
			Sum(hfd.demand) as Demand,
			1 as observed
FROM        vHourlyFcstDemand hfd
GROUP BY	hfd.PUFcstPeriod, hfd.PUFcstZone, hfd.TripIndex

GO

----------------  vHourlySupply  ------------------------------------------------------

IF EXISTS(select * FROM sys.views where name = 'vHourlySupply')
DROP VIEW [dbo].[vHourlySupply]
GO

CREATE VIEW [dbo].[vHourlySupply]
AS
SELECT      hfd.DOFcstPeriod as FcstPeriod,
 			hfd.DOFcstZone as FcstZone, 
			hfd.TripIndex as TripIndex, 
			max(hfd.DOFcstPeriodDate) as FcstPeriodDate,
			Sum(hfd.demand) as Supply,
			1 as observed
FROM        vHourlyFcstDemand hfd
GROUP BY	hfd.DOFcstPeriod, hfd.DOFcstZone, hfd.TripIndex

GO

----------------  vHourlyOverSupply  ------------------------------------------------------

IF EXISTS(select * FROM sys.views where name = 'vHourlyOverSupply')
DROP VIEW [dbo].[vHourlyOverSupply]
GO

CREATE VIEW [dbo].[vHourlyOverSupply]
AS
	select hs.FcstPeriod, hs.FcstZone, hs.Supply - hd.Demand as OverSupply,
			1 as observed
	from vHourlySupply hs
	Left JOIN vHourlyZoneDemand hd ON hs.FcstPeriod = hd.FcstPeriod AND hs.FcstZone = hd.FcstZone
	where hs.supply > hd.Demand
GO

---------------  vHourlyUnderSupply  ------------------------------------------------------

IF EXISTS(select * FROM sys.views where name = 'vHourlyUnderSupply')
DROP VIEW [dbo].[vHourlyUnderSupply]
GO

CREATE VIEW [dbo].[vHourlyUnderSupply]
AS
	select hs.FcstPeriod, hs.FcstZone, hd.Demand - hs.Supply as UnderSupply,
			1 as observed
	from vHourlySupply hs
	Left JOIN vHourlyZoneDemand hd ON hs.FcstPeriod = hd.FcstPeriod AND hs.FcstZone = hd.FcstZone
	where hs.supply < hd.Demand
GO



-----------------  vZoneDistances  ------------------------------------------------------

IF EXISTS(select * FROM sys.views where name = 'vZoneDistances')
DROP VIEW [dbo].[vZoneDistances]
GO

CREATE VIEW [dbo].[vZoneDistances]
AS
	SELECT 1000000 + (t.PULocationID * 1000) + t.DOLocationID AS TripIndex, 
		t.PULocationID, t.DOLocationID,  AVG(t.tripDistance) as AverageTrip
	FROM RawTripData t
	GROUP BY t.DOLocationID, t.PULocationID
GO


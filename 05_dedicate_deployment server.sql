

------------------- hourly Zone Demand  -----------------------------------------------

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[HourlyZoneDemand]') AND type in (N'U'))
DROP TABLE [dbo].[HourlyZoneDemand]
GO

CREATE TABLE [dbo].[HourlyZoneDemand](
	[FcstPeriod] [int] NULL,
	[FcstZone] [int] NULL,
	[Demand] [int] NULL
) 
GO

------------------- hourly Over Supply  -----------------------------------------------

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[HourlyOverSupply]') AND type in (N'U'))
DROP TABLE [dbo].[HourlyOverSupply]
GO

CREATE TABLE [dbo].[HourlyOverSupply](
	[FcstPeriod] [int] NULL,
	[FcstZone] [int] NULL,
	[OverSupply] [int] NULL
) 
GO

------------------- Hourly Under Supply  -----------------------------------------------

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[HourlyUnderSupply]') AND type in (N'U'))
DROP TABLE [dbo].[HourlyUnderSupply]
GO

CREATE TABLE [dbo].[HourlyUnderSupply](
	[FcstPeriod] [int] NULL,
	[FcstZone] [int] NULL,
	[UnderSupply] [int] NULL
)
GO


-------------------  Deploy Orders  -----------------------------------------------

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DeployOrders]') AND type in (N'U'))
DROP TABLE [dbo].[DeployOrders]
GO

CREATE TABLE [dbo].[DeployOrders](
	[FcstPeriod] [int] NULL,
	[FcstZone] [int] NULL,
	[FromLocation] [int] NULL,
	[Supply] [int] NULL
) 
GO


-------------------------------------------------------------------------------
----------------  Views  ------------------------------------------------------
-------------------------------------------------------------------------------

----------------  vHourlyFcstDemand  ------------------------------------------------------

IF EXISTS(select * FROM sys.views where name = 'vHourlyFcstDemand')
DROP VIEW [dbo].[vHourlyFcstDemand]
GO

CREATE VIEW [dbo].[vHourlyFcstDemand]
AS
SELECT      FcstYear * 1000000 + FcstMonth * 10000 + FcstDay * 100 + FcstHour as PUFcstPeriod,
		    DATEPART(Year, DATEADD(MINUTE, zd.AverageDuration, DATETIMEFROMPARTS (FcstYear, FcstMonth, FcstDay, FcstHour, 0, 0, 0))) * 1000000 + 
                DATEPART(month, DATEADD(MINUTE, zd.AverageDuration, DATETIMEFROMPARTS (FcstYear, FcstMonth, FcstDay, FcstHour, 0, 0, 0))) * 10000 + 
                DATEPART(day, DATEADD(MINUTE, zd.AverageDuration, DATETIMEFROMPARTS (FcstYear, FcstMonth, FcstDay, FcstHour, 0, 0, 0))) * 100 + 
                DATEPART(hour, DATEADD(MINUTE, zd.AverageDuration, DATETIMEFROMPARTS (FcstYear, FcstMonth, FcstDay, FcstHour, 0, 0, 0))) as DOFcstPeriod,
			DATETIMEFROMPARTS (FcstYear, FcstMonth, FcstDay, FcstHour, 0, 0, 0) as PUFcstPeriodDate,
            DATEADD(MINUTE, zd.AverageDuration, DATETIMEFROMPARTS (FcstYear, FcstMonth, FcstDay, FcstHour, 0, 0, 0)) as DOFcstPeriodDate,
 			zd.puLocationId as PUFcstZone, 
			zd.doLocationID as DOFcstZone, 
			FcstYear as PUYear, 
			FcstMonth as PUMonth, 
			FcstDay as PUDay, 
			FcstHour as PUHour, 
			fd.TripIndex as TripIndex, 
			Demand as demand
FROM        FcstZoneDemand fd
INNER JOIN  ZoneDistances zd ON zd.puLocationID = (fd.TripIndex - 1000000) / 1000 AND zd.DOLocationID = (fd.TripIndex - 1000000) - (((fd.TripIndex - 1000000) / 1000)) * 1000


GO

----------------  vHourlyDemand  ------------------------------------------------------

IF EXISTS(select * FROM sys.views where name = 'vHourlyDemand')
DROP VIEW [dbo].[vHourlyDemand]
GO

CREATE VIEW [dbo].[vHourlyDemand]
AS
SELECT      hfd.PUFcstPeriod as FcstPeriod,
 			hfd.PUFcstZone as FcstZone, 
			Sum(hfd.demand) as Demand
FROM        vHourlyFcstDemand hfd
GROUP BY	hfd.PUFcstPeriod, hfd.PUFcstZone

GO

----------------  vHourlySupply  ------------------------------------------------------

IF EXISTS(select * FROM sys.views where name = 'vHourlySupply')
DROP VIEW [dbo].[vHourlySupply]
GO

CREATE VIEW [dbo].[vHourlySupply]
AS
SELECT      hfd.DOFcstPeriod as FcstPeriod,
 			hfd.DOFcstZone as FcstZone, 
			Sum(hfd.demand) as Supply
FROM        vHourlyFcstDemand hfd
GROUP BY	hfd.DOFcstPeriod, hfd.DOFcstZone

GO

----------------  vHourlyOverSupply  ------------------------------------------------------

IF EXISTS(select * FROM sys.views where name = 'vHourlyOverSupply')
DROP VIEW [dbo].[vHourlyOverSupply]
GO

CREATE VIEW [dbo].[vHourlyOverSupply]
AS
	select	hs.FcstPeriod, 
			hs.FcstZone, 
			hs.Supply - hd.Demand as OverSupply
	from vHourlySupply hs
	Left JOIN vHourlyDemand hd ON hs.FcstPeriod = hd.FcstPeriod AND hs.FcstZone = hd.FcstZone
	where hs.supply > hd.Demand
GO

---------------  vHourlyUnderSupply  ------------------------------------------------------

IF EXISTS(select * FROM sys.views where name = 'vHourlyUnderSupply')
DROP VIEW [dbo].[vHourlyUnderSupply]
GO

CREATE VIEW [dbo].[vHourlyUnderSupply]
AS
	select hs.FcstPeriod, hs.FcstZone, hd.Demand - hs.Supply as UnderSupply
	from vHourlySupply hs
	Left JOIN vHourlyDemand hd ON hs.FcstPeriod = hd.FcstPeriod AND hs.FcstZone = hd.FcstZone
	where hs.supply < hd.Demand
GO


------------------------------------------------------------------------------------------------------------------
-----------------------   Deploy Proc  -----------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------

/****** Object:  StoredProcedure [dbo].[up_MakeDeployOrders]    Script Date: 12 Jun 2021 11:27:20 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--EXEC up_MakeDeployOrders 2019070100, 2019070124

CREATE PROCEDURE [dbo].[up_MakeDeployOrders] 
(
	@FromFcstPeriod int,
	@ToFcstPeriod int
)
AS
BEGIN

	--DECLARE @FromFcstPeriod int
	--DECLARE @ToFcstPeriod int
	--SET @FromFcstPeriod = 2018012900
	--SET @ToFcstPeriod = 2018012924

	SET NOCOUNT ON 

	------------------------------------------------
	-------------   Load Data  ---------------------
	------------------------------------------------


	TRUNCATE TABLE [dbo].[HourlyZoneDemand]
	INSERT INTO HourlyZoneDemand
	SELECT * FROM vHourlyDemand

	TRUNCATE TABLE [dbo].[HourlyOverSupply]
	INSERT INTO HourlyOverSupply
	SELECT 
		FcstPeriod,
		FcstZone,
		OverSupply
	FROM vHourlyOverSupply

	TRUNCATE TABLE [dbo].[HourlyUnderSupply]
	INSERT INTO HourlyUnderSupply
	SELECT  
		FcstPeriod,
		FcstZone,
		UnderSupply
	FROM vHourlyUnderSupply

	---  Create temp tables  -----------

	IF OBJECT_ID('tempdb..#DeployOrders') IS NOT NULL 
		DROP TABLE #DeployOrders

	CREATE TABLE #DeployOrders (
		[FcstPeriod] [int] NULL,
		[FcstZone] [int] NULL,
		[FromLocation] [int] NULL,
		[Needed] [int] NULL,
		[Supplied] [int] NULL
	)

	IF OBJECT_ID('tempdb..#UnderSupply') IS NOT NULL 
		DROP TABLE #UnderSupply

	CREATE TABLE #UnderSupply (
		[IDX] [int] NOT NULL,
		[FcstPeriod] [int] NULL,
		[FcstZone] [int] NULL,
		[UnderSupply] [int] NULL
	) 

	IF OBJECT_ID('tempdb..#Available') IS NOT NULL 
		DROP TABLE #Available

	CREATE TABLE #Available (
		[IDX] [int] NOT NULL,
		LocationID int, 
		Available int
	)

	DECLARE @FcstZone int
	DECLARE @FcstPeriod int
	DECLARE @UnderSupply int
	DECLARE @Available int
	DECLARE @AvailableLocationID int
	DECLARE @UnderSupplyRecords int
	DECLARE @UnderSupplyCurrentRecord int
	DECLARE @AvailableRecords int
	DECLARE @AvailableCurrentRecord int

	-- Get records to iterate through
	INSERT INTO #UnderSupply
		SELECT
			ROW_NUMBER() OVER (ORDER BY FcstPeriod, FcstZone),
			FcstPeriod,
			FcstZone,
			UnderSupply
		FROM HourlyUnderSupply
		WHERE FcstPeriod BETWEEN @FromFcstPeriod AND @ToFcstPeriod

	SET @UnderSupplyCurrentRecord = 0

	SELECT @UnderSupplyRecords = Count(*) from #UnderSupply

	WHILE @UnderSupplyCurrentRecord < @UnderSupplyRecords
	BEGIN
		SET @UnderSupplyCurrentRecord += 1

		SELECT 
			@FcstPeriod = FcstPeriod,
			@FcstZone = FcstZone,
			@UnderSupply = UnderSupply
		FROM #UnderSupply
		WHERE IDX = @UnderSupplyCurrentRecord

		TRUNCATE TABLE #Available

		INSERT INTO #Available
			SELECT
				ROW_NUMBER() OVER (ORDER BY zd.AverageTrip),
				zd.PULocationID as LocationID, 
				hos.OverSupply as Available
			FROM HourlyUnderSupply hus
				INNER JOIN ZoneDistances zd ON hus.FcstZone = zd.DOLocationID 
				INNER JOIN HourlyOverSupply hos ON hos.FcstZone = zd.PULocationID AND hos.FcstPeriod = hus.FcstPeriod
			WHERE hus.FcstZone = @FcstZone
				AND hus.FcstPeriod = @FcstPeriod
		
		SET @AvailableCurrentRecord = 0

		SELECT @AvailableRecords = Count(*) from #Available

		WHILE @AvailableCurrentRecord < @AvailableRecords
		BEGIN
			SET @AvailableCurrentRecord += 1

			SELECT 
				@Available = Available,
				@AvailableLocationID = LocationID
			FROM #Available
			WHERE IDX = @AvailableCurrentRecord

			IF @UnderSupply > 0
			BEGIN
				IF @Available <= @UnderSupply
				BEGIN
					UPDATE #Available
						SET Available = 0
					WHERE IDX = @AvailableCurrentRecord
				
					INSERT INTO #DeployOrders (FcstPeriod, FcstZone, FromLocation, Needed, Supplied)
					VALUES (@FcstPeriod, @FcstZone, @AvailableLocationID, @UnderSupply, @Available)

					SET @UnderSupply -= @Available

				END
				ELSE
				BEGIN
					UPDATE #Available
						SET Available = @Available - @UnderSupply
					WHERE IDX = @AvailableCurrentRecord

					INSERT INTO #DeployOrders (FcstPeriod, FcstZone, FromLocation, Needed, Supplied)
					VALUES (@FcstPeriod, @FcstZone, @AvailableLocationID, @UnderSupply, @UnderSupply)

					SET @UnderSupply = 0

					BREAK
				END
			END
		END
	END

	DELETE FROM DeployOrders 
	WHERE FcstPeriod BETWEEN @FromFcstPeriod AND @ToFcstPeriod

	INSERT INTO DeployOrders (FcstPeriod, FcstZone, FromLocation, Supply)
	SELECT FcstPeriod, FcstZone, FromLocation, Supplied
	FROM #DeployOrders
	
END


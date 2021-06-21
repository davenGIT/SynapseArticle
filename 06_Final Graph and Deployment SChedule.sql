-- This script is the data for thr final graph ouput showing 
-- the relationship between the supply and suggested deployment
Select 
    d.FcstPeriod, 
    AVG(ISNULL(d.demand, 0)) as demand, 
    AVG(ISNULL(us.underSupply, 0)) as undersupply, 
    AVG(ISNULL(os.overSupply, 0)) as oversupply,
    SUM(ISNULL(do.Supply, 0)) as SuggestedDeployment 
from HourlyZoneDemand d
left join HourlyunderSupply us on us.FcstPeriod = d.FcstPeriod and us.fcstZone = d.fcstZone
left join HourlyOverSupply os on os.FcstPeriod = d.FcstPeriod and os.fcstZone = d.fcstZone
left join DeployOrders do on do.FcstPeriod = d.FcstPeriod and do.FcstZone = d.FcstZone
where d.fcstzone = 161
Group by d.fcstPeriod
order by d.fcstPeriod


-- This script is the basis for the deployment report 
-- and shows the breakdown of the deployments and where the taxis will be 
-- deployed from
Select d.FcstPeriod, d.UnderSupply, do.Supply, do.FromLocation, zd.AverageTrip
from HourlyunderSupply d
INNER JOIN DeployOrders do on do.FcstPeriod = d.FcstPeriod AND do.FcstZone = d.FcstZone
INNER JOIN ZoneDistances zd on zd.PULocationID = do.FcstZone and zd.DOLocationID = do.FromLocation
where d.fcstzone = 161
order by d.fcstPeriod , zd.AverageTrip
 
 

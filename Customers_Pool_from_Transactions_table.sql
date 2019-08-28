
/*
this customers pool model takes 2016 as first year of activity 
period here is half year, but can be adjusted to quarters or months etc.
all customers are devide into 1 of 5 groups in the pool:
	new customer = first purchase in the last period 
	active customer = purchased at least ones in each of previous two periods
	reactivated customer = purchased in the last period, did not purchase in the period before but did purchase before that
	churn-signal customer = did not purchase in the last period, but did purchase in the period before
	churned customer = did not purchase in the last two periods, but did purchase before that
*/

IF OBJECT_ID('tempdb..#HalfYearsSummary') IS NOT NULL
   DROP TABLE #HalfYearsSummary
SELECT UserID,   
[2016-1], [2016-2], [2017-1], [2017-2], [2018-1], [2018-2]
INTO #HalfYearsSummary  
FROM (SELECT DISTINCT UserID, TransactionID,
             (CAST(YEAR(OrderCreationDate) AS nvarchar(4)) + '-' + CASE WHEN DATEPART(quarter, OrderCreationDate) <= 2 THEN '1' ELSE '2' END) AS TimePeriod
      FROM OrdersTable
      WHERE OrderCreationDate >= '20160101'
      ) AS SourceTable
PIVOT (COUNT(TransactionID) FOR TimePeriod IN ([2016-1], [2016-2], [2017-1], [2017-2], [2018-1], [2018-2])) AS PivotTable;  


SELECT
       COUNT(CASE WHEN [2018-1] > 0 AND [2017-2] = 0 AND [2017-1] = 0 AND [2016-2] = 0 AND [2016-1] = 0 THEN UserID END) AS 'new Q1 2018',
       COUNT(CASE WHEN [2018-2] > 0 AND [2018-1] = 0 AND [2017-2] = 0 AND [2017-1] = 0 AND [2016-2] = 0 AND [2016-1] = 0 THEN UserID END) AS 'new Q2 2018',
       COUNT(CASE WHEN [2017-1] > 0 AND [2016-2] = 0 AND [2016-1] = 0 THEN UserID END) AS 'new Q1 2017',
       COUNT(CASE WHEN [2017-2] > 0 AND [2017-1] = 0 AND [2016-2] = 0 AND [2016-1] = 0 THEN UserID END) AS 'new Q2 2017', 
       COUNT(CASE WHEN [2016-1] > 0 THEN UserID END) AS 'new Q1 2016',
       COUNT(CASE WHEN [2016-2] > 0 AND [2016-1] = 0 THEN UserID END) AS 'new Q2 2016', 


       COUNT(CASE WHEN [2018-1] > 0 AND [2017-2] > 0 THEN UserID END) AS 'active Q1 2018',
       COUNT(CASE WHEN [2018-2] > 0 AND [2018-1] > 0 THEN UserID END) AS 'active Q2 2018',
       COUNT(CASE WHEN [2017-1] > 0 AND [2016-2] > 0 THEN UserID END) AS 'active Q1 2017',
       COUNT(CASE WHEN [2017-2] > 0 AND [2017-1] > 0 THEN UserID END) AS 'active Q2 2017',
       0 AS 'active Q1 2016',
       COUNT(CASE WHEN [2016-2] > 0 AND [2016-1] > 0 THEN UserID END) AS 'active Q2 2016',


       COUNT(CASE WHEN [2018-1] > 0 AND [2017-2] = 0 AND ([2017-1] > 0 OR [2016-2] > 0 OR [2016-1] > 0) THEN UserID END) AS 'reactivated Q1 2018',
       COUNT(CASE WHEN [2018-2] > 0 AND [2018-1] = 0 AND ([2017-2] > 0 OR [2017-1] > 0 OR [2016-2] > 0 OR [2016-1] > 0) THEN UserID END) AS 'reactivated Q2 2018',
       COUNT(CASE WHEN [2017-1] > 0 AND [2016-2] = 0 AND ([2016-1] > 0) THEN UserID END) AS 'reactivated Q1 2017',
       COUNT(CASE WHEN [2017-2] > 0 AND [2017-1] = 0 AND ([2016-2] > 0 OR [2016-1] > 0) THEN UserID END) AS 'reactivated Q2 2017', 
       0 AS 'reactivated Q1 2016',
       0 AS 'reactivated Q2 2016', 


       COUNT(CASE WHEN [2018-1] = 0 AND [2017-2] > 0 THEN UserID END) AS 'churn-signal Q1 2018',
       COUNT(CASE WHEN [2018-2] = 0 AND [2018-1] > 0 THEN UserID END) AS 'churn-signal Q2 2018',
       COUNT(CASE WHEN [2017-1] = 0 AND [2016-2] > 0 THEN UserID END) AS 'churn-signal Q1 2017',
       COUNT(CASE WHEN [2017-2] = 0 AND [2017-1] > 0 THEN UserID END) AS 'churn-signal Q2 2017', 
       0 AS 'churn-signal Q1 2016',
       COUNT(CASE WHEN [2016-2] = 0 AND [2016-1] > 0 THEN UserID END) AS 'churn-signal Q2 2016', 


       COUNT(CASE WHEN [2018-1] = 0 AND [2017-2] = 0 AND ([2017-1] > 0 OR [2016-2] > 0 OR [2016-1] > 0) THEN UserID END) AS 'churned Q1 2018',
       COUNT(CASE WHEN [2018-2] = 0 AND [2018-1] = 0 AND ([2017-2] > 0 OR [2017-1] > 0 OR [2016-2] > 0 OR [2016-1] > 0) THEN UserID END) AS 'churned Q2 2018',
       COUNT(CASE WHEN [2017-1] = 0 AND [2016-2] = 0 AND ([2016-1] > 0) THEN UserID END) AS 'churned Q1 2017',
       COUNT(CASE WHEN [2017-2] = 0 AND [2017-1] = 0 AND ([2016-2] > 0 OR [2016-1] > 0) THEN UserID END) AS 'churned Q2 2017',
       0 AS 'churned Q1 2016',
       0 AS 'churned Q2 2016'

FROM #HalfYearsSummary




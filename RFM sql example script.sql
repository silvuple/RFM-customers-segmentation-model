
/*
create variables for the start and end date of the RFM analysis
e.g. 2018 calendar year, or last 12 months
*/
DECLARE @StartDate datetime = '2018-01-01'
DECLARE @EndDate datetime = '2019-01-01'


/* 
Select relevant transactions from database 
e.g. remove fraudulent transactions, company employees,
business customers and/or other outliers
*/
IF OBJECT_ID('tempdb..#TransactionForRFM') IS NOT NULL
   DROP TABLE #TransactionForRFM

-- create CTE with all transactions that are good for the model
WITH RelevantTransactions (TransactionID) AS 
(
	SELECT TransactionID 
	FROM TransactionsTable WITH (NOLOCK)
	WHERE TransactionAmount < 10000 AND Comments NOT LIKE 'Fraud' -- exclude large transactions and frauds for example
),
RelevantUsers (UserID) AS
(
	SELECT UserID
	FROM UsersTable
	WHERE Employee = 0  -- exclude employees
)
-- select all the relevant data in the analysis period
SELECT *  
INTO #TransactionForRFM
FROM TransactionsTable tt WITH (NOLOCK)
JOIN RelevantTransactions rt ON tt.TransactionID = rt.TransactionID
JOIN RelevantUsers ru ON tt.UserID = ru.UserID
WHERE TransactionDate BETWEEN @StartDate AND @EndDate


/*
Aggregate data per customer and further remove outliers
e.g. customers with more than 100 transactions in the period
*/
IF OBJECT_ID('tempdb..#RFMUsers') IS NOT NULL
   DROP TABLE #RFMUsers

SELECT UserID,
       DATEDIFF(day, MAX(TransactionDate), @EndDate) AS [DaysSinceLastPurchase],
       COUNT(DISTINCT TransactionID) AS [NumberOfTransactions],
	   SUM(TransactionAmount) AS [TotalPurchaseAmount]
INTO #RFMUsers
FROM #TransactionForRFM
GROUP BY UserID
HAVING COUNT(DISTINCT TransactionID) <= 100  


/*
Check cumulative distribution of each of the 3 parameters to decide on values for RFM model
*/
SELECT TOP 1 * FROM (SELECT PERCENTILE_CONT(0.25) WITHIN GROUP(ORDER BY [DaysSinceLastPurchase]) OVER() AS [cume_dist] FROM #RFMUsers) t
SELECT TOP 1 * FROM (SELECT PERCENTILE_CONT(0.50) WITHIN GROUP(ORDER BY [DaysSinceLastPurchase]) OVER() AS [cume_dist] FROM #RFMUsers) t
SELECT TOP 1 * FROM (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP(ORDER BY [DaysSinceLastPurchase]) OVER() AS [cume_dist] FROM #RFMUsers) t

SELECT TOP 1 * FROM (SELECT PERCENTILE_CONT(0.25) WITHIN GROUP(ORDER BY [NumberOfTransactions]) OVER() AS [cume_dist] FROM #RFMUsers) t
SELECT TOP 1 * FROM (SELECT PERCENTILE_CONT(0.50) WITHIN GROUP(ORDER BY [NumberOfTransactions]) OVER() AS [cume_dist] FROM #RFMUsers) t
SELECT TOP 1 * FROM (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP(ORDER BY [NumberOfTransactions]) OVER() AS [cume_dist] FROM #RFMUsers) t

SELECT TOP 1 * FROM (SELECT PERCENTILE_CONT(0.25) WITHIN GROUP(ORDER BY [TotalPurchaseAmount]) OVER() AS [cume_dist] FROM #RFMUsers) t
SELECT TOP 1 * FROM (SELECT PERCENTILE_CONT(0.50) WITHIN GROUP(ORDER BY [TotalPurchaseAmount]) OVER() AS [cume_dist] FROM #RFMUsers) t
SELECT TOP 1 * FROM (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP(ORDER BY [TotalPurchaseAmount]) OVER() AS [cume_dist] FROM #RFMUsers) t


/*
Create R(Recency), F(Frequency), M(Monetary) values per customer
*/
IF OBJECT_ID('tempdb..#RFM') IS NOT NULL
   DROP TABLE #RFM

SELECT *,
	   CASE WHEN [DaysSinceLastPurchase] <= 60  THEN 1 
		    WHEN [DaysSinceLastPurchase] <= 180 THEN 2
		    WHEN [DaysSinceLastPurchase] >  180 THEN 3 
	   END AS Recency,

       PERCENT_RANK( ) OVER (ORDER BY [DaysSinceLastPurchase] DESC) AS R_PercentRank,
	   CUME_DIST( ) OVER (ORDER BY [DaysSinceLastPurchase] DESC) AS R_CumeDist,

       CASE WHEN [NumberOfTransactions] >= 3 THEN 1 
            WHEN [NumberOfTransactions] =  2 THEN 2
            WHEN [NumberOfTransactions] =  1 THEN 3 
	   END AS Frequency,
	   
	   PERCENT_RANK( ) OVER (ORDER BY [NumberOfTransactions]) AS F_PercentRank,
	   CUME_DIST( ) OVER (ORDER BY [NumberOfTransactions]) AS F_CumeDist,

       CASE WHEN [TotalPurchaseAmount] >= 600 THEN 1 
            WHEN [TotalPurchaseAmount] >= 200 THEN 2
            WHEN [TotalPurchaseAmount] <  200 THEN 3 
	   END AS MonetaryValue,
  
	   PERCENT_RANK( ) OVER (ORDER BY [TotalPurchaseAmount])  AS M_PercentRank,
	   CUME_DIST( ) OVER (ORDER BY [TotalPurchaseAmount])  AS M_CumeDist

INTO #RFM
FROM #RFMUsers


/*
Devide customers into groups based on their RFM values
*/
SELECT *, 
        CASE WHEN Recency IN (1, 2) AND Frequency = 1 AND MonetaryValue = 1 THEN 'Platinum'
             WHEN Recency IN (3) AND Frequency = 1 AND MonetaryValue = 1 THEN 'Churn-signal Platinum'
             WHEN Recency IN (1, 2) AND Frequency = 1 AND MonetaryValue IN (2, 3) THEN 'Gold'
             WHEN Recency IN (3) AND Frequency = 1 AND MonetaryValue IN (2, 3) THEN 'Churn-signal Gold'
             WHEN Recency IN (1, 2) AND Frequency = 2 AND MonetaryValue IN (1, 2, 3) THEN 'Silver'
             WHEN Recency IN (3) AND Frequency = 2 AND MonetaryValue IN (1, 2, 3) THEN 'Churn-signal Silver'
             WHEN Recency IN (1, 2) AND Frequency = 3 AND MonetaryValue IN (1, 2, 3) THEN 'One-timers'
             WHEN Recency IN (3) AND Frequency = 3 AND MonetaryValue IN (1, 2, 3) THEN 'Churn-signal One-timers'
        END AS [RFMGroup]
FROM #RFM

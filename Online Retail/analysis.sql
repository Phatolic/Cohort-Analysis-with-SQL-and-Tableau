SELECT TOP (1000) [InvoiceNo]
      ,[StockCode]
      ,[Description]
      ,[Quantity]
      ,[InvoiceDate]
      ,[UnitPrice]
      ,[CustomerID]
      ,[Country]
  FROM [online_retail].[dbo].[online_retail];

---Cleaning data
WITH clean1 AS (
	SELECT *, ROW_NUMBER() OVER (PARTITION BY InvoiceNo,StockCode,Quantity,InvoiceDate,CustomerID,Country ORDER BY InvoiceNo) AS  dup
	FROM online_retail
	WHERE CustomerID IS NOT NULL AND CustomerID !=0 AND Quantity > 0 AND UnitPrice >0
), clean2 AS (
	SELECT *
	FROM clean1
	WHERE dup = 1
)
--- Insert into temp table
	SELECT *
	INTO #online_retail_main
	FROM clean2;

---Cohort Analysis
---As the number of customers
WITH t1 AS(
	SELECT CustomerID,InvoiceDate,  CAST(FORMAT(InvoiceDate,'yyyy-MM-01') AS date) AS order_month --- Order Month
	FROM #online_retail_main 
),t2 AS (
	SELECT CustomerID, CAST(FORMAT(MIN(InvoiceDate),'yyyy-MM-01') AS date) AS cohort_month ---First Purchase Month
	FROM #online_retail_main
	GROUP BY CustomerID
), t3 AS (
	SELECT t1.*,t2.cohort_month,DATEDIFF(month,cohort_month,order_month) + 1  AS cohort_index
	FROM t1	
		JOIN t2 ON t1.CustomerID =t2.CustomerID
)
	SELECT order_month,cohort_month,cohort_index,COUNT(DISTINCT CustomerID) AS Customers
	FROM t3
	GROUP BY order_month,cohort_month,cohort_index;


---As the percentage of customers
WITH t1 AS(
	SELECT CustomerID,InvoiceDate,  CAST(FORMAT(InvoiceDate,'yyyy-MM-01') AS date) AS order_month	
	FROM #online_retail_main 
),t2 AS (
	SELECT CustomerID, CAST(FORMAT(MIN(InvoiceDate),'yyyy-MM-01') AS date) AS cohort_month
	FROM #online_retail_main
	GROUP BY CustomerID
), t3 AS (
	SELECT t1.*,t2.cohort_month,DATEDIFF(month,cohort_month,order_month) + 1  AS cohort_index
	FROM t1	
		JOIN t2 ON t1.CustomerID =t2.CustomerID
),one AS (
	SELECT order_month,cohort_month,cohort_index,COUNT(DISTINCT CustomerID) AS Customers
	FROM t3
	GROUP BY order_month,cohort_month,cohort_index
)
	---Take the first value of the count of customers as 100% for every cohort month.
	SELECT one.*, FIRST_VALUE(Customers) OVER (PARTITION BY cohort_month ORDER BY cohort_index) AS cohort_size, CAST(Customers AS float) / FIRST_VALUE(Customers) OVER (PARTITION BY cohort_month ORDER BY cohort_index) AS pct_retained
	FROM one
	ORDER BY cohort_month

--PIVOT
WITH cte AS (
	SELECT DATEPART(year,InvoiceDate) AS year,DATEPART(quarter,InvoiceDate) AS quarter,(UnitPrice * Quantity) AS sales
	FROM #online_retail_main
), cte2 AS (
	SELECT year,quarter,sum(sales) AS tong_doanh_thu
	FROM CTE
	GROUP BY year ,quarter
)
	SELECT *
	FROM cte2
		pivot (
			SUM(tong_doanh_thu) FOR quarter IN ([1], [2], [3], [4])
		) AS X

	
-- UNPIVOT
WITH cte AS (
	SELECT DATEPART(year,InvoiceDate) AS year,DATEPART(quarter,InvoiceDate) AS quarter,(UnitPrice * Quantity) AS sales
	FROM #online_retail_main
), cte2 AS (
	SELECT year,quarter,sum(sales) AS tong_doanh_thu
	FROM CTE
	GROUP BY year ,quarter
), cte3 AS (	
	SELECT *
	FROM cte2
		pivot (
			SUM(tong_doanh_thu) FOR quarter IN ([1],[2],[3],[4])
		) AS X
)
	SELECT year, quarter, sales
	FROM cte3
	UNPIVOT (
		sales FOR quarter IN ([1], [2], [3], [4])
	) AS Y

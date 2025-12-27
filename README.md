# -Parameter-Sniffing-in-SQL-Server
##**Demonstrates the impact of parameter sniffing on execution plans and performance in SQL Server. Compares simple SPs, dynamic SQL, and OPTION(RECOMPILE to mitigate performance issues.**

## Scripts
All SQL scripts used in this project are available in the Scripts/ folder:

1. Creating Table
 ```SQL
DROP TABLE IF EXISTS dbo.Orders;
GO

CREATE TABLE dbo.Orders (
    OrderID INT IDENTITY PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATE NOT NULL,
    Amount DECIMAL(10,2) NOT NULL
);
GO
```
   
2. Inserting 1000000 skewed sample data (large and small customers):
```SQL
INSERT INTO dbo.Orders (CustomerID, OrderDate, Amount)
SELECT
    CASE 
        WHEN n <= 400000 THEN 1
        ELSE ABS(CHECKSUM(NEWID())) % 5000 + 2
    END,
    DATEADD(DAY, -n % 365, GETDATE()),
    ABS(CHECKSUM(NEWID())) % 1000
FROM (
    SELECT TOP (1000000)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM master..spt_values a
CROSS JOIN master..spt_values b
) x;
GO
SELECT COUNT(*) FROM ORDERS;
GO
```
3.Creating a non-clustered index on CustomerID to optimize query performance:
```SQL
DROP INDEX IF EXISTS IX_Orders_CustomerID ON dbo.Orders;
GO
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID
ON dbo.Orders (CustomerID)
INCLUDE (OrderDate, Amount);
GO
```
4. Creating SimpleSP
```SQL
DROP PROC IF EXISTS dbo.usp_GetOrdersByCustomer;
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetOrdersByCustomer
    @CustomerID INT
AS
BEGIN
    SELECT OrderID, OrderDate, Amount
    FROM dbo.Orders
    WHERE CustomerID = @CustomerID;
END
GO
```
5.Testing Simple SP with a customer that has many orders
```sql
EXEC dbo.usp_GetOrdersByCustomer @CustomerID = 1;
GO
```
execution plan:

6.Testing Simple SP with a customer that has few orders:
```sql
SELECT TOP 1 CustomerID, COUNT(*) AS Cnt
FROM dbo.Orders
GROUP BY CustomerID
ORDER BY COUNT(*) ASC;  --CUSTID=895 CNT=80
GO
EXEC dbo.usp_GetOrdersByCustomer @CustomerID = 895;
GO
```
execution plan:

7. Creating DynamicSP
```sql
CREATE OR ALTER PROCEDURE dbo.usp_GetOrdersByCustomer_Dynamic
    @CustomerID INT
AS
BEGIN
    DECLARE @sql NVARCHAR(MAX) =
        N'SELECT OrderID, OrderDate, Amount
          FROM dbo.Orders
          WHERE CustomerID = @CustomerID';

    EXEC sp_executesql
        @sql,
        N'@CustomerID INT',
        @CustomerID;
END
GO
```
8.Testing DynamicSP with a customer that has many orders
```SQL
EXEC dbo.usp_GetOrdersByCustomer_Dynamic @CustomerID = 1;
GO
```
execution plan:

9. Creating Simple stored procedure with OPTION(RECOMPILE).
```sql
DROP PROC IF EXISTS dbo.usp_GetOrdersByCustomer_Recompile;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetOrdersByCustomer_Recompile
    @CustomerID INT
AS
BEGIN
    SELECT OrderID, OrderDate, Amount
    FROM dbo.Orders
    WHERE CustomerID = @CustomerID
    OPTION (RECOMPILE);
END
GO
```
10. Testing Simple SP WITH OPTION(RECOMPILE) with a customer that has many orders
 ```SQL
    EXEC dbo.usp_GetOrdersByCustomer_Recompile @CustomerID = 1;
    GO
    ```
EXECUTION PLAN:
11. Testing Simple SP WITH OPTION(RECOMPILE) with a customer that has few orders
```SQL
EXEC dbo.usp_GetOrdersByCustomer_Recompile @CustomerID = 895;
GO
```
EXECUTION PLAN:


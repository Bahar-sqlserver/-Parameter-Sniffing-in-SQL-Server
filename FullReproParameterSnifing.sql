DROP TABLE IF EXISTS dbo.Orders;
GO

CREATE TABLE dbo.Orders (
    OrderID INT IDENTITY PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATE NOT NULL,
    Amount DECIMAL(10,2) NOT NULL
);
GO

   --CustomerID = 1 → ~40%
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
    FROM master.sys.all_objects a
CROSS JOIN master.sys.all_objects b
) x;
GO
SELECT COUNT(*) FROM ORDERS;
GO

   --INDEX

DROP INDEX IF EXISTS IX_Orders_CustomerID ON dbo.Orders;
GO
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID
ON dbo.Orders (CustomerID)
INCLUDE (OrderDate, Amount);
GO

  --Simple SP
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


   --TEST 
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
DBCC DROPCLEANBUFFERS;
GO

-- First execution (large customer → bad plan cached)
EXEC dbo.usp_GetOrdersByCustomer @CustomerID = 1;
GO


-- Second execution (small customer → reuses bad plan)
SELECT TOP 1 CustomerID, COUNT(*) AS Cnt
FROM dbo.Orders
GROUP BY CustomerID
ORDER BY COUNT(*) ASC;  --CUSTID=895 CNT=80

EXEC dbo.usp_GetOrdersByCustomer @CustomerID = 895;
GO


   --FIX 1 – RECOMPILE

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

EXEC dbo.usp_GetOrdersByCustomer_Recompile @CustomerID = 1;

EXEC dbo.usp_GetOrdersByCustomer_Recompile @CustomerID = 895;
GO

   --FIX 2 – DYNAMIC SQL
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

EXEC dbo.usp_GetOrdersByCustomer_Dynamic @CustomerID = 1;

EXEC dbo.usp_GetOrdersByCustomer_Dynamic @CustomerID = 895;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

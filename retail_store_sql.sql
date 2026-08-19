USE Work;
GO

SELECT *
FROM dbo.retail_store_sales
WHERE Category = 'Milk Products';
-------------------------------------

-- STEP 1
-- Create a copy of the raw table.

SELECT *
INTO dbo.retail_store_sales_cleaned
FROM dbo.retail_store_sales;
-------------------------------------

-- STEP 2
-- Inspect the data.

SELECT *
FROM dbo.retail_store_sales_cleaned;
-------------------------------------

-- STEP 3
-- Check duplicate Transaction IDs.
WITH cte AS (
    SELECT Transaction_ID,
    ROW_NUMBER() OVER (PARTITION BY Transaction_ID ORDER BY Transaction_ID) AS rn
    FROM dbo.retail_store_sales_cleaned
)
SELECT *
FROM cte
WHERE rn > 1;
-------------------------------------

-- STEP 4
-- Trim spaces.
UPDATE dbo.retail_store_sales_cleaned
SET 
    Transaction_ID = LTRIM(RTRIM(Transaction_ID)),
    Customer_ID = LTRIM(RTRIM(Customer_ID)),
    Item = LTRIM(RTRIM(Item)),
    Category = LTRIM(RTRIM(Category)),
    Price_Per_Unit = LTRIM(RTRIM(Price_Per_Unit)),
    Quantity = LTRIM(RTRIM(Quantity)),
    Total_Spent = LTRIM(RTRIM(Total_Spent)),
    Payment_Method = LTRIM(RTRIM(Payment_Method)),
    [Location] = LTRIM(RTRIM([Location])),
    Discount_Applied = LTRIM(RTRIM(Discount_Applied)),
    Transaction_Date = LTRIM(RTRIM(Transaction_Date));
-------------------------------------

-- STEP 5
-- Standardize text values.
UPDATE dbo.retail_store_sales_cleaned
SET 
    Item = UPPER(Item),
    Category = UPPER(Category),
    Payment_Method = UPPER(Payment_Method),
    [Location] = UPPER([Location]);
-------------------------------------

-- STEP 6
-- Convert Transaction Date to datetime.

UPDATE dbo.retail_store_sales_cleaned
SET Transaction_Date = TRY_CAST(Transaction_Date AS DATETIME)
WHERE Transaction_Date IS NOT NULL;
-------------------------------------

-- STEP 7
-- Handle missing Item values.
BEGIN TRANSACTION;
UPDATE dbo.retail_store_sales_cleaned
SET Item = CASE 
    WHEN Category = 'Patisserie' THEN 'Unknown_PATISSERIE'
    WHEN Category = 'Milk Products' THEN 'Unknown_MILK'
    WHEN Category = 'Food' THEN 'Unknown_FOOD'
    WHEN Category = 'Computer and electronic accessories' THEN 'Unknown_COMPUTER'
    WHEN Category = 'Butchers' THEN 'Unknown_BUTCHER'
    WHEN Category = 'Electric household essentials' THEN 'Unknown_ELECTRIC_HOUSEHOLD'
    WHEN Category = 'Beverages' THEN 'Unknown_BEVERAGE'
    WHEN Category = 'Furniture' THEN 'Unknown_FURNITURE'
    ELSE 'Unknown Item'
END
WHERE Item IS NULL OR Item = '';
COMMIT TRANSACTION;
-------------------------------------

-- STEP 8
-- Calculate missing Price Per Unit.
BEGIN TRANSACTION;
UPDATE dbo.retail_store_sales_cleaned
SET Price_Per_Unit = Total_Spent / Quantity
WHERE Price_Per_Unit IS NULL 
AND Quantity IS NOT NULL 
AND Total_Spent IS NOT NULL;
COMMIT TRANSACTION;

-------------------------------------

-- STEP 9
-- Calculate missing Quantity.
BEGIN TRANSACTION;
UPDATE dbo.retail_store_sales_cleaned
SET Quantity = Total_Spent / Price_Per_Unit
WHERE Quantity IS NULL 
AND Price_Per_Unit IS NOT NULL 
AND Total_Spent IS NOT NULL;
COMMIT TRANSACTION;

-------------------------------------

-- STEP 10
-- Calculate missing Total Spent.
BEGIN TRANSACTION;
UPDATE dbo.retail_store_sales_cleaned
SET Total_Spent = Price_Per_Unit * Quantity
WHERE Total_Spent IS NULL 
AND Price_Per_Unit IS NOT NULL 
AND Quantity IS NOT NULL;
COMMIT TRANSACTION;
-------------------------------------

-- STEP 11
-- Convert 1/0 values to True / False.
ALTER TABLE dbo.retail_store_sales_cleaned
ALTER COLUMN Discount_Boolean varchar(5);

UPDATE dbo.retail_store_sales_cleaned
SET Discount_Boolean = CASE
    WHEN Discount_Boolean = 1 THEN 'True'
    WHEN Discount_Boolean = 0 THEN 'False'
    ELSE 'False'
END;

SELECT *
FROM dbo.retail_store_sales_cleaned;
-------------------------------------

-- STEP 12
-- Validate Total Spent = Price * Quantity
ALTER TABLE dbo.retail_store_sales_cleaned
ADD Total_Spent_Validation AS (Price_Per_Unit * Quantity);

UPDATE dbo.retail_store_sales_cleaned
SET Total_Spent = total_Spent_Validation
WHERE Total_Spent <> Total_Spent_Validation;

ALTER TABLE dbo.retail_store_sales_cleaned
DROP COLUMN Total_Spent_Validation;

-------------------------------------

-- STEP 13
-- Check invalid numbers.
SELECT *
FROM dbo.retail_store_sales_cleaned
WHERE Price_Per_Unit < 0 
OR Quantity < 0 
OR Total_Spent < 0;

-------------------------------------

-- STEP 14
-- Perform final validation.

ALTER TABLE dbo.retail_store_sales_cleaned
ALTER COLUMN Price_Per_Unit DECIMAL(10, 2);

ALTER TABLE dbo.retail_store_sales_cleaned
ALTER COLUMN Quantity INT;

ALTER TABLE dbo.retail_store_sales_cleaned
ALTER COLUMN Total_Spent DECIMAL(10, 2);
-------------------------------------

-- STEP 15
-- Export cleaned dataset.
SELECT *
INTO dbo.retail_store_sales_final
FROM dbo.retail_store_sales_cleaned;

ALTER TABLE dbo.retail_store_sales_final
DROP COLUMN Discount_Applied;

SELECT DISTINCT Transaction_Date
FROM dbo.retail_store_sales_final
ORDER BY Transaction_Date;

SELECT DISTINCT Category
FROM dbo.retail_store_sales_final;

SELECT DISTINCT Payment_Method
FROM dbo.retail_store_sales_final;

SELECT DISTINCT [Location]
FROM dbo.retail_store_sales_final;

SELECT *
FROM dbo.retail_store_sales_final;
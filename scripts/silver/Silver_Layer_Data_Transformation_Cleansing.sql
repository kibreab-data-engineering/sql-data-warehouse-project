/*
=======================================================================================================================
Script Name:
    Silver Layer Data Transformation and Cleansing

Layer:
    Bronze --> Silver

Purpose:
--------
This script performs data cleansing, standardization, validation,
and transformation operations while loading data from the Bronze Layer
(raw source data) into the Silver Layer (cleaned and transformed data).

The Silver Layer represents structured, validated, and business-ready data
used for reporting, analytics, and downstream Gold Layer processing.

Main Objectives:
----------------
1. Remove duplicate records.
2. Handle NULL and invalid values.
3. Standardize inconsistent data values.
4. Clean leading/trailing spaces.
5. Apply business transformation rules.
6. Validate relationships between entities.
7. Correct invalid date and numeric values.
8. Improve overall data quality.

Data Flow:
----------
Bronze Layer (Raw Data)
        -->
Silver Layer (Cleaned & Standardized Data)

Target Silver Tables:
---------------------
CRM:
    - silver.crm_cust_info
    - silver.crm_prd_info
    - silver.crm_sales_details

ERP:
    - silver.erp_cust_az12
    - silver.erp_loc_a101
    - silver.erp_px_cat_g1v2

Important Notes:
----------------
1. This process uses FULL REFRESH loading.
   Existing Silver table data is removed before loading new data.

2. Data quality validations are included before and after transformations.

3. Transformation rules include:
      - Data trimming
      - Standardization
      - Null handling
      - Duplicate removal
      - Data type conversion
      - Relationship validation
      - Business rule corrections

4. The script assumes Bronze tables are already populated.

Warning:
--------
TRUNCATE TABLE statements permanently delete existing data
from Silver tables before reloading.

Execute only after validating Bronze Layer data.

=======================================================================================================================
*/

USE DatawareHouse;
GO

/*=====================================================================================================================
    CRM CUSTOMER INFORMATION
=====================================================================================================================*/

-- Review Source Data
SELECT *
FROM [bronze].[crm_cust_info];



/*-------------------------------------------------------------------------------------------------------------
    Data Quality Check
    Check for NULL or Duplicate Primary Keys

    Expectation:
        No duplicate or NULL cst_id values
-------------------------------------------------------------------------------------------------------------*/
SELECT DISTINCT
       cst_id,
       COUNT(*) AS record_count
FROM [bronze].[crm_cust_info]
GROUP BY cst_id
HAVING COUNT(*) > 1
    OR cst_id IS NULL;
GO



/*-------------------------------------------------------------------------------------------------------------
    Load Cleaned Data into Silver Layer
-------------------------------------------------------------------------------------------------------------*/

TRUNCATE TABLE [silver].[crm_cust_info];

INSERT INTO [silver].[crm_cust_info]
(
    [cst_id],
    [cst_key],
    [cst_firstname],
    [cst_lastname],
    [cst_marital_status],
    [cst_gndr],
    [cst_create_date]
)

SELECT
    [cst_id],
    [cst_key],

    -- Remove leading/trailing spaces
    TRIM([cst_firstname]) AS [cst_firstname],

    TRIM([cst_lastname]) AS [cst_lastname],

    -- Standardize marital status values
    CASE
        WHEN UPPER(TRIM([cst_marital_status])) = 'S' THEN 'Single'
        WHEN UPPER(TRIM([cst_marital_status])) = 'M' THEN 'Married'
        ELSE 'N/A'
    END AS [cst_marital_status],

    -- Standardize gender values
    CASE
        WHEN UPPER(TRIM([cst_gndr])) = 'F' THEN 'Female'
        WHEN UPPER(TRIM([cst_gndr])) = 'M' THEN 'Male'
        ELSE 'N/A'
    END AS [cst_gndr],

    [cst_create_date]

FROM
(
    -- Keep latest customer record based on create date
    SELECT *,
           ROW_NUMBER() OVER
           (
               PARTITION BY cst_id
               ORDER BY cst_create_date DESC
           ) AS flag_last
    FROM [bronze].[crm_cust_info]
) T

WHERE flag_last = 1
  AND cst_id IS NOT NULL;



/*-------------------------------------------------------------------------------------------------------------
    Validation Tests
-------------------------------------------------------------------------------------------------------------*/

-- Check for unwanted spaces
SELECT DISTINCT [cst_marital_status]
FROM [bronze].[crm_cust_info]
WHERE [cst_marital_status] <> TRIM([cst_marital_status]);

-- Review Silver Data
SELECT *
FROM [silver].[crm_cust_info];

-- Validate cleaned last names
SELECT DISTINCT [cst_lastname]
FROM [silver].[crm_cust_info]
WHERE [cst_lastname] <> TRIM([cst_lastname]);



/*=====================================================================================================================
    CRM PRODUCT INFORMATION
=====================================================================================================================*/

TRUNCATE TABLE [silver].[crm_prd_info];

INSERT INTO [silver].[crm_prd_info]
(
    [prd_id],
    [cat_id],
    [prd_key],
    [prd_nm],
    [prd_cost],
    [prd_line],
    [prd_start_dt],
    [prd_end_dt]
)

SELECT
    [prd_id],

    -- Create category ID
    REPLACE(SUBSTRING([prd_key], 1, 5), '-', '_') AS cat_id,

    -- Extract product key
    SUBSTRING([prd_key], 7, LEN([prd_key])) AS [prd_key],

    [prd_nm],

    -- Replace NULL costs with 0
    ISNULL([prd_cost], 0) AS [prd_cost],

    -- Standardize product line values
    CASE
        WHEN UPPER(TRIM([prd_line])) = 'M' THEN 'Mountain'
        WHEN UPPER(TRIM([prd_line])) = 'R' THEN 'Road'
        WHEN UPPER(TRIM([prd_line])) = 'S' THEN 'Other Sales'
        WHEN UPPER(TRIM([prd_line])) = 'T' THEN 'Touring'
        ELSE 'N/A'
    END AS [prd_line],

    CAST([prd_start_dt] AS DATE) AS [prd_start_dt],

    -- Derive end date using LEAD function
    CAST
    (
        LEAD([prd_start_dt])
        OVER
        (
            PARTITION BY prd_key
            ORDER BY [prd_start_dt]
        ) AS DATE
    ) AS [prd_end_dt]

FROM [bronze].[crm_prd_info];



/*-------------------------------------------------------------------------------------------------------------
    Validation Tests
-------------------------------------------------------------------------------------------------------------*/

-- Validate product date ranges
SELECT
    [prd_key],
    CAST([prd_start_dt] AS DATE) AS [prd_start_dt],
    CAST([prd_end_dt] AS DATE) AS [prd_end_dt]
FROM [silver].[crm_prd_info]
ORDER BY 1;

-- Check invalid date ranges
SELECT DISTINCT [prd_cost]
FROM [silver].[crm_prd_info]
WHERE [prd_start_dt] > [prd_end_dt];

-- Check duplicate product IDs
SELECT
    [prd_id],
    COUNT(*) AS record_count
FROM [bronze].[crm_prd_info]
GROUP BY prd_id
HAVING COUNT(*) > 1;



/*=====================================================================================================================
    CRM SALES DETAILS
=====================================================================================================================*/

TRUNCATE TABLE [silver].[crm_sales_details];

INSERT INTO [silver].[crm_sales_details]
(
    [sls_ord_num],
    [sls_prd_key],
    [sls_cust_id],
    [sls_order_dt],
    [sls_ship_dt],
    [sls_due_dt],
    [sls_sales],
    [sls_quantity],
    [sls_price]
)

SELECT
    [sls_ord_num],
    [sls_prd_key],
    [sls_cust_id],

    -- Convert invalid order dates to NULL
    CASE
        WHEN [sls_order_dt] = 0
          OR LEN([sls_order_dt]) != 8
        THEN NULL
        ELSE CAST(CAST([sls_order_dt] AS VARCHAR) AS DATE)
    END AS [sls_order_dt],

    -- Convert invalid ship dates to NULL
    CASE
        WHEN [sls_ship_dt] = 0
          OR LEN([sls_ship_dt]) != 8
        THEN NULL
        ELSE CAST(CAST([sls_ship_dt] AS VARCHAR) AS DATE)
    END AS [sls_ship_dt],

    -- Convert invalid due dates to NULL
    CASE
        WHEN [sls_due_dt] = 0
          OR LEN([sls_due_dt]) != 8
        THEN NULL
        ELSE CAST(CAST([sls_due_dt] AS VARCHAR) AS DATE)
    END AS [sls_due_dt],

    -- Recalculate invalid sales amounts
    CASE
        WHEN sls_sales IS NULL
          OR sls_sales <= 0
          OR sls_sales != sls_quantity * ABS(sls_price)
        THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales
    END AS [sls_sales],

    [sls_quantity],

    -- Recalculate invalid prices
    CASE
        WHEN [sls_price] IS NULL
          OR [sls_price] <= 0
        THEN sls_sales / NULLIF([sls_quantity], 0)
        ELSE [sls_price]
    END AS [sls_price]

FROM [bronze].[crm_sales_details];



/*-------------------------------------------------------------------------------------------------------------
    Validation Tests
-------------------------------------------------------------------------------------------------------------*/

-- Check order number formatting
SELECT sls_ord_num
FROM [bronze].[crm_sales_details]
WHERE sls_ord_num <> TRIM(sls_ord_num);

-- Validate customer relationships
SELECT sls_cust_id
FROM [bronze].[crm_sales_details]
WHERE sls_cust_id NOT IN
(
    SELECT cst_id
    FROM [silver].[crm_cust_info]
);

-- Validate product relationships
SELECT sls_prd_key
FROM [bronze].[crm_sales_details]
WHERE sls_prd_key NOT IN
(
    SELECT prd_key
    FROM [silver].[crm_prd_info]
);

-- Review corrected sales calculations
SELECT
    sls_sales AS OLD_sls_sales,
    sls_quantity,
    sls_price,

    CASE
        WHEN sls_sales IS NULL
          OR sls_sales <= 0
          OR sls_sales != sls_quantity * ABS(sls_price)
        THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales
    END AS NEW_sls_sales,

    CASE
        WHEN sls_price IS NULL
          OR sls_price <= 0
        THEN sls_sales / NULLIF(sls_quantity, 0)
        ELSE sls_price
    END AS NEW_sls_price

FROM [bronze].[crm_sales_details]

WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0;

-- Check duplicate product keys
SELECT
    sls_prd_key,
    COUNT(*) AS record_count
FROM [bronze].[crm_sales_details]
GROUP BY sls_prd_key
HAVING COUNT(*) > 1;

-- Review final Silver sales data
SELECT *
FROM [silver].[crm_sales_details];



/*=====================================================================================================================
    ERP CUSTOMER DATA
=====================================================================================================================*/

TRUNCATE TABLE [silver].[erp_cust_az12];

INSERT INTO [silver].[erp_cust_az12]
(
    [cid],
    [bdate],
    [gen]
)

SELECT

    -- Remove NAS prefix from customer IDs
    CASE
        WHEN cid LIKE 'NAS%'
        THEN SUBSTRING([cid], 4, LEN([cid]))
        ELSE cid
    END AS cid,

    -- Remove future birthdates
    CASE
        WHEN [bdate] > GETDATE()
        THEN NULL
        ELSE [bdate]
    END AS [bdate],

    -- Standardize gender values
    CASE
        WHEN UPPER(TRIM([gen])) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM([gen])) IN ('M', 'MALE') THEN 'Male'
        ELSE 'N/A'
    END AS [gen]

FROM [bronze].[erp_cust_az12];



/*-------------------------------------------------------------------------------------------------------------
    Validation Tests
-------------------------------------------------------------------------------------------------------------*/

-- Validate customer relationship with CRM customer table
SELECT
    CASE
        WHEN cid LIKE 'NAS%'
        THEN SUBSTRING([cid], 4, LEN([cid]))
        ELSE cid
    END AS cid,
    [bdate],
    [gen]

FROM [bronze].[erp_cust_az12]

WHERE CASE
          WHEN cid LIKE 'NAS%'
          THEN SUBSTRING([cid], 4, LEN([cid]))
          ELSE cid
      END NOT IN
(
    SELECT cst_key
    FROM [bronze].[crm_cust_info]
);

-- Review distinct gender values
SELECT DISTINCT gen
FROM [silver].[erp_cust_az12];



/*=====================================================================================================================
    ERP LOCATION DATA
=====================================================================================================================*/

TRUNCATE TABLE [silver].[erp_loc_a101];

INSERT INTO [silver].[erp_loc_a101]
(
    [cid],
    [cntry]
)

SELECT

    -- Remove hyphens from customer IDs
    REPLACE([cid], '-', '') AS [cid],

    -- Standardize country names
    CASE
        WHEN TRIM([cntry]) IN ('US', 'USA', 'United States')
            THEN 'United States'

        WHEN TRIM([cntry]) IN ('DE', 'Germany')
            THEN 'Germany'

        WHEN TRIM([cntry]) IS NULL
          OR TRIM([cntry]) = ''
            THEN 'N/A'

        ELSE [cntry]
    END AS [cntry]

FROM [bronze].[erp_loc_a101];



/*-------------------------------------------------------------------------------------------------------------
    Validation Tests
-------------------------------------------------------------------------------------------------------------*/

-- Review standardized country values
SELECT DISTINCT
       CASE
           WHEN [cntry] IN ('US', 'USA', 'United States')
               THEN 'United States'

           WHEN [cntry] IN ('DE', 'Germany')
               THEN 'Germany'

           WHEN [cntry] IS NULL
             OR TRIM([cntry]) = ''
               THEN 'N/A'

           ELSE [cntry]
       END AS [cntry]

FROM [bronze].[erp_loc_a101];

-- Validate customer relationship
SELECT
    REPLACE([cid], '-', '') AS [cid],
    [cntry]

FROM [bronze].[erp_loc_a101]

WHERE REPLACE([cid], '-', '') NOT IN
(
    SELECT cst_key
    FROM [bronze].[crm_cust_info]
);



/*=====================================================================================================================
    ERP PRODUCT CATEGORY DATA
=====================================================================================================================*/

-- Review source data
SELECT TOP 2 *
FROM [bronze].[erp_px_cat_g1v2];

-- Review related product data
SELECT *
FROM [silver].[crm_prd_info];

-- Check unwanted spaces
SELECT DISTINCT maintenance
FROM [bronze].[erp_px_cat_g1v2]
WHERE maintenance <> TRIM(maintenance);



/*-------------------------------------------------------------------------------------------------------------
    Load Product Category Data
-------------------------------------------------------------------------------------------------------------*/

TRUNCATE TABLE [silver].[erp_px_cat_g1v2];

INSERT INTO [silver].[erp_px_cat_g1v2]
(
    [id],
    [cat],
    [subcat],
    [maintenance]
)

SELECT *
FROM [bronze].[erp_px_cat_g1v2];



/*-------------------------------------------------------------------------------------------------------------
    Validation Test
-------------------------------------------------------------------------------------------------------------*/

SELECT *
FROM [silver].[erp_px_cat_g1v2];

GO

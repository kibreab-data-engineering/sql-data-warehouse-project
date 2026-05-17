/*
=======================================================================================================================
Stored Procedure: silver.load_silver
=======================================================================================================================

Purpose:
--------
This stored procedure loads and transforms data from the Bronze Layer
(raw source data) into the Silver Layer (cleaned and standardized data).

The procedure performs:
    - Data cleansing
    - Data standardization
    - Duplicate removal
    - Null handling
    - Business rule transformations
    - Data type corrections

Data Flow:
----------
Bronze Layer  -->  Silver Layer

Source Tables:
--------------
CRM:
    - bronze.crm_cust_info
    - bronze.crm_prd_info
    - bronze.crm_sales_details

ERP:
    - bronze.erp_cust_az12
    - bronze.erp_loc_a101
    - bronze.erp_px_cat_g1v2

Target Tables:
--------------
CRM:
    - silver.crm_cust_info
    - silver.crm_prd_info
    - silver.crm_sales_details

ERP:
    - silver.erp_cust_az12
    - silver.erp_loc_a101
    - silver.erp_px_cat_g1v2

Transformation Rules:
---------------------
CRM Customer:
    - Remove duplicates
    - Keep latest customer record
    - Trim spaces
    - Standardize marital status
    - Standardize gender values

CRM Product:
    - Generate category ID
    - Extract product key
    - Replace NULL product cost
    - Standardize product line values
    - Generate product end dates

CRM Sales:
    - Convert invalid dates to NULL
    - Recalculate invalid sales amounts
    - Recalculate invalid prices

ERP Customer:
    - Remove NAS prefix from customer IDs
    - Remove future birth dates
    - Standardize gender values

ERP Location:
    - Remove hyphens from customer IDs
    - Standardize country names

ERP Product Category:
    - Direct load from Bronze to Silver

Parameters:
-----------
This stored procedure does not accept parameters.

Usage Example:
--------------
EXEC silver.load_silver;

Important Notes:
----------------
1. This procedure uses FULL REFRESH logic.
   Existing Silver table data is deleted before reloading.

2. TRUNCATE TABLE is used for performance optimization.

3. The Bronze Layer must be loaded successfully before executing this procedure.

4. Intended for ETL batch processing.

Warning:
--------
Executing this procedure will permanently remove existing data
from Silver tables before loading fresh transformed data.

=======================================================================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @start_time        DATETIME;
    DECLARE @end_time          DATETIME;
    DECLARE @batch_start_time  DATETIME;
    DECLARE @batch_end_time    DATETIME;

    BEGIN TRY

        SET @batch_start_time = GETDATE();

        PRINT '===================================================================================================================';
        PRINT '                                             Loading Silver Layer';
        PRINT '===================================================================================================================';



        /*=============================================================================================================
            CRM CUSTOMER INFORMATION
        =============================================================================================================*/

        PRINT '********************************************************************************************************************';
        PRINT 'Loading CRM Customer Information';
        PRINT '********************************************************************************************************************';

        SET @start_time = GETDATE();

        PRINT '>> Truncating table: silver.crm_cust_info';

        TRUNCATE TABLE [silver].[crm_cust_info];

        PRINT '>> Inserting data into: silver.crm_cust_info';

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

            TRIM([cst_firstname]) AS [cst_firstname],

            TRIM([cst_lastname]) AS [cst_lastname],

            CASE
                WHEN UPPER(TRIM([cst_marital_status])) = 'S' THEN 'Single'
                WHEN UPPER(TRIM([cst_marital_status])) = 'M' THEN 'Married'
                ELSE 'N/A'
            END AS [cst_marital_status],

            CASE
                WHEN UPPER(TRIM([cst_gndr])) = 'F' THEN 'Female'
                WHEN UPPER(TRIM([cst_gndr])) = 'M' THEN 'Male'
                ELSE 'N/A'
            END AS [cst_gndr],

            [cst_create_date]

        FROM
        (
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

        SET @end_time = GETDATE();

        PRINT '>>>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
              + ' Seconds';

        PRINT '--------------------------------------------------------------------------------------------------------------------';



        /*=============================================================================================================
            CRM PRODUCT INFORMATION
        =============================================================================================================*/

        PRINT '********************************************************************************************************************';
        PRINT 'Loading CRM Product Information';
        PRINT '********************************************************************************************************************';

        SET @start_time = GETDATE();

        PRINT '>> Truncating table: silver.crm_prd_info';

        TRUNCATE TABLE [silver].[crm_prd_info];

        PRINT '>> Inserting data into: silver.crm_prd_info';

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

            REPLACE(SUBSTRING([prd_key], 1, 5), '-', '_') AS cat_id,

            SUBSTRING([prd_key], 7, LEN([prd_key])) AS [prd_key],

            [prd_nm],

            ISNULL([prd_cost], 0) AS [prd_cost],

            CASE
                WHEN UPPER(TRIM([prd_line])) = 'M' THEN 'Mountain'
                WHEN UPPER(TRIM([prd_line])) = 'R' THEN 'Road'
                WHEN UPPER(TRIM([prd_line])) = 'S' THEN 'Other Sales'
                WHEN UPPER(TRIM([prd_line])) = 'T' THEN 'Touring'
                ELSE 'N/A'
            END AS [prd_line],

            CAST([prd_start_dt] AS DATE) AS [prd_start_dt],

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

        SET @end_time = GETDATE();

        PRINT '>>>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
              + ' Seconds';

        PRINT '--------------------------------------------------------------------------------------------------------------------';



        /*=============================================================================================================
            CRM SALES DETAILS
        =============================================================================================================*/

        PRINT '********************************************************************************************************************';
        PRINT 'Loading CRM Sales Details';
        PRINT '********************************************************************************************************************';

        SET @start_time = GETDATE();

        PRINT '>> Truncating table: silver.crm_sales_details';

        TRUNCATE TABLE [silver].[crm_sales_details];

        PRINT '>> Inserting data into: silver.crm_sales_details';

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

            CASE
                WHEN [sls_order_dt] = 0
                  OR LEN([sls_order_dt]) != 8
                THEN NULL
                ELSE CAST(CAST([sls_order_dt] AS VARCHAR) AS DATE)
            END AS [sls_order_dt],

            CASE
                WHEN [sls_ship_dt] = 0
                  OR LEN([sls_ship_dt]) != 8
                THEN NULL
                ELSE CAST(CAST([sls_ship_dt] AS VARCHAR) AS DATE)
            END AS [sls_ship_dt],

            CASE
                WHEN [sls_due_dt] = 0
                  OR LEN([sls_due_dt]) != 8
                THEN NULL
                ELSE CAST(CAST([sls_due_dt] AS VARCHAR) AS DATE)
            END AS [sls_due_dt],

            CASE
                WHEN sls_sales IS NULL
                  OR sls_sales <= 0
                  OR sls_sales != sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END AS [sls_sales],

            [sls_quantity],

            CASE
                WHEN [sls_price] IS NULL
                  OR [sls_price] <= 0
                THEN sls_sales / NULLIF([sls_quantity], 0)
                ELSE [sls_price]
            END AS [sls_price]

        FROM [bronze].[crm_sales_details];

        SET @end_time = GETDATE();

        PRINT '>>>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
              + ' Seconds';

        PRINT '--------------------------------------------------------------------------------------------------------------------';



        /*=============================================================================================================
            ERP CUSTOMER INFORMATION
        =============================================================================================================*/

        PRINT '********************************************************************************************************************';
        PRINT 'Loading ERP Customer Information';
        PRINT '********************************************************************************************************************';

        SET @start_time = GETDATE();

        PRINT '>> Truncating table: silver.erp_cust_az12';

        TRUNCATE TABLE [silver].[erp_cust_az12];

        PRINT '>> Inserting data into: silver.erp_cust_az12';

        INSERT INTO [silver].[erp_cust_az12]
        (
            [cid],
            [bdate],
            [gen]
        )

        SELECT
            CASE
                WHEN cid LIKE 'NAS%'
                THEN SUBSTRING([cid], 4, LEN([cid]))
                ELSE cid
            END AS cid,

            CASE
                WHEN [bdate] > GETDATE()
                THEN NULL
                ELSE [bdate]
            END AS [bdate],

            CASE
                WHEN UPPER(TRIM([gen])) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM([gen])) IN ('M', 'MALE') THEN 'Male'
                ELSE 'N/A'
            END AS [gen]

        FROM [bronze].[erp_cust_az12];

        SET @end_time = GETDATE();

        PRINT '>>>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
              + ' Seconds';

        PRINT '--------------------------------------------------------------------------------------------------------------------';



        /*=============================================================================================================
            ERP LOCATION INFORMATION
        =============================================================================================================*/

        PRINT '********************************************************************************************************************';
        PRINT 'Loading ERP Location Information';
        PRINT '********************************************************************************************************************';

        SET @start_time = GETDATE();

        PRINT '>> Truncating table: silver.erp_loc_a101';

        TRUNCATE TABLE [silver].[erp_loc_a101];

        PRINT '>> Inserting data into: silver.erp_loc_a101';

        INSERT INTO [silver].[erp_loc_a101]
        (
            [cid],
            [cntry]
        )

        SELECT
            REPLACE([cid], '-', '') AS [cid],

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

        SET @end_time = GETDATE();

        PRINT '>>>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
              + ' Seconds';

        PRINT '--------------------------------------------------------------------------------------------------------------------';



        /*=============================================================================================================
            ERP PRODUCT CATEGORY INFORMATION
        =============================================================================================================*/

        PRINT '********************************************************************************************************************';
        PRINT 'Loading ERP Product Category Information';
        PRINT '********************************************************************************************************************';

        SET @start_time = GETDATE();

        PRINT '>> Truncating table: silver.erp_px_cat_g1v2';

        TRUNCATE TABLE [silver].[erp_px_cat_g1v2];

        PRINT '>> Inserting data into: silver.erp_px_cat_g1v2';

        INSERT INTO [silver].[erp_px_cat_g1v2]
        (
            [id],
            [cat],
            [subcat],
            [maintenance]
        )

        SELECT
            [id],
            [cat],
            [subcat],
            [maintenance]

        FROM [bronze].[erp_px_cat_g1v2];

        SET @end_time = GETDATE();

        SET @batch_end_time = GETDATE();

        PRINT '>>>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR(20))
              + ' Seconds';

        PRINT '--------------------------------------------------------------------------------------------------------------------';



        /*=============================================================================================================
            COMPLETION MESSAGE
        =============================================================================================================*/

        PRINT '===================================================================================================================';
        PRINT 'Silver Layer Loading Completed Successfully';
        PRINT 'Total Batch Duration: '
              + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS VARCHAR(20))
              + ' Seconds';
        PRINT '===================================================================================================================';

    END TRY

    BEGIN CATCH

        PRINT '=========================================================';
        PRINT 'ERROR OCCURRED DURING SILVER LAYER LOAD';
        PRINT 'ERROR MESSAGE : ' + ERROR_MESSAGE();
        PRINT 'ERROR NUMBER  : ' + CAST(ERROR_NUMBER() AS VARCHAR(20));
        PRINT '=========================================================';

    END CATCH

END;
GO


/*=====================================================================================================================
    Usage Example
=====================================================================================================================*/

EXEC silver.load_silver;
GO

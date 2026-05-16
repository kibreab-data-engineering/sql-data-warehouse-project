/*
=======================================================================================================================
Stored Procedure: bronze.load_bronze
=======================================================================================================================

Purpose:
--------
This stored procedure is responsible for loading raw source data files (CSV format)
from CRM and ERP source systems into the Bronze Layer tables of the Data Warehouse.

The Bronze Layer represents the raw ingestion layer where source data is loaded
without applying transformations or business rules.

Main Activities:
----------------
1. Truncate existing Bronze tables.
2. Load fresh data using BULK INSERT from CSV files.
3. Capture and print load duration for each table.
4. Capture and print total batch duration.
5. Handle errors using TRY...CATCH.

Data Flow:
----------
Source CSV Files  -->  Bronze Layer Tables

Source Systems:
---------------
CRM Source:
    - cust_info.csv
    - prd_info.csv
    - sales_details.csv

ERP Source:
    - cust_az12.csv
    - loc_a101.csv
    - px_cat_g1v2.csv

Target Bronze Tables:
---------------------
CRM Tables:
    - bronze.crm_cust_info
    - bronze.crm_prd_info
    - bronze.crm_sales_details

ERP Tables:
    - bronze.erp_cust_az12
    - bronze.erp_loc_a101
    - bronze.erp_px_cat_g1v2

Parameters:
-----------
This stored procedure does not accept any parameters.

Usage Example:
--------------
-- Execute the Bronze Layer Load
EXEC bronze.load_bronze;

Important Notes:
----------------
1. This procedure performs FULL REFRESH loads.
   Existing table data is removed using TRUNCATE TABLE before loading new data.

2. Source CSV files must exist in the specified file paths.

3. SQL Server service account must have access to the source file locations.

4. BULK INSERT requires proper permissions:
      - ADMINISTER BULK OPERATIONS
      OR
      - BULKADMIN role membership

5. FIRSTROW = 2 skips the CSV header row.

6. TABLOCK improves bulk load performance.

7. This procedure is intended for development/demo environments.
   For production:
      - Use configurable file paths
      - Add logging tables
      - Add validation checks
      - Add audit tracking
      - Add transaction handling

Warning:
--------
TRUNCATE TABLE permanently removes all existing data from the target tables
before new data is loaded.

Do NOT execute this procedure unless:
    - Source files are validated
    - Backup/recovery strategy exists
    - Downstream processes are ready for refresh

=======================================================================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN

    DECLARE @start_tme        DATETIME;
    DECLARE @end_time         DATETIME;
    DECLARE @batch_start_time DATETIME;
    DECLARE @batch_end_time   DATETIME;

    BEGIN TRY

        PRINT '===================================================================================================================';
        PRINT '                                                   Loading Bronze Layer';
        PRINT '===================================================================================================================';

        SET @batch_start_time = GETDATE();

        /*=============================================================================================================
            CRM TABLES
        =============================================================================================================*/

        PRINT '********************************************************************************************************************';
        PRINT 'Loading CRM Tables';
        PRINT '********************************************************************************************************************';

        /*-------------------------------------------------------------------------------------------------------------
            Load: bronze.crm_cust_info
        -------------------------------------------------------------------------------------------------------------*/
        SET @start_tme = GETDATE();

        PRINT '>> Truncating table: bronze.crm_cust_info';

        TRUNCATE TABLE bronze.crm_cust_info;

        PRINT '>> Inserting data into bronze.crm_cust_info';

        BULK INSERT bronze.crm_cust_info
        FROM 'C:\Users\KB\Documents\sql-data-warehouse-project\datasets\source_crm\cust_info.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();

        PRINT '>>>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_tme, @end_time) AS VARCHAR(50))
              + ' Seconds';

        PRINT '--------------------------------------------------------------------------------------------------------------------';

        /*-------------------------------------------------------------------------------------------------------------
            Load: bronze.crm_prd_info
        -------------------------------------------------------------------------------------------------------------*/
        SET @start_tme = GETDATE();

        PRINT '>> Truncating table: bronze.crm_prd_info';

        TRUNCATE TABLE bronze.crm_prd_info;

        PRINT '>> Inserting data into bronze.crm_prd_info';

        BULK INSERT bronze.crm_prd_info
        FROM 'C:\Users\KB\Documents\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();

        PRINT '>>>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_tme, @end_time) AS VARCHAR(50))
              + ' Seconds';

        PRINT '--------------------------------------------------------------------------------------------------------------------';

        /*-------------------------------------------------------------------------------------------------------------
            Load: bronze.crm_sales_details
        -------------------------------------------------------------------------------------------------------------*/
        SET @start_tme = GETDATE();

        PRINT '>> Truncating table: bronze.crm_sales_details';

        TRUNCATE TABLE bronze.crm_sales_details;

        PRINT '>> Inserting data into bronze.crm_sales_details';

        BULK INSERT bronze.crm_sales_details
        FROM 'C:\Users\KB\Documents\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();

        PRINT '>>>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_tme, @end_time) AS VARCHAR(50))
              + ' Seconds';

        PRINT '--------------------------------------------------------------------------------------------------------------------';

        /*=============================================================================================================
            ERP TABLES
        =============================================================================================================*/

        PRINT '********************************************************************************************************************';
        PRINT 'Loading ERP Tables';
        PRINT '********************************************************************************************************************';

        /*-------------------------------------------------------------------------------------------------------------
            Load: bronze.erp_cust_az12
        -------------------------------------------------------------------------------------------------------------*/
        SET @start_tme = GETDATE();

        PRINT '>> Truncating table: bronze.erp_cust_az12';

        TRUNCATE TABLE bronze.erp_cust_az12;

        PRINT '>> Inserting data into bronze.erp_cust_az12';

        BULK INSERT bronze.erp_cust_az12
        FROM 'C:\Users\KB\Documents\sql-data-warehouse-project\datasets\source_erp\cust_az12.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();

        PRINT '>>>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_tme, @end_time) AS VARCHAR(50))
              + ' Seconds';

        PRINT '--------------------------------------------------------------------------------------------------------------------';

        /*-------------------------------------------------------------------------------------------------------------
            Load: bronze.erp_loc_a101
        -------------------------------------------------------------------------------------------------------------*/
        SET @start_tme = GETDATE();

        PRINT '>> Truncating table: bronze.erp_loc_a101';

        TRUNCATE TABLE bronze.erp_loc_a101;

        PRINT '>> Inserting data into bronze.erp_loc_a101';

        BULK INSERT bronze.erp_loc_a101
        FROM 'C:\Users\KB\Documents\sql-data-warehouse-project\datasets\source_erp\loc_a101.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();

        PRINT '>>>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_tme, @end_time) AS VARCHAR(50))
              + ' Seconds';

        PRINT '--------------------------------------------------------------------------------------------------------------------';

        /*-------------------------------------------------------------------------------------------------------------
            Load: bronze.erp_px_cat_g1v2
        -------------------------------------------------------------------------------------------------------------*/
        SET @start_tme = GETDATE();

        PRINT '>> Truncating table: bronze.erp_px_cat_g1v2';

        TRUNCATE TABLE bronze.erp_px_cat_g1v2;

        PRINT '>> Inserting data into bronze.erp_px_cat_g1v2';

        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'C:\Users\KB\Documents\sql-data-warehouse-project\datasets\source_erp\px_cat_g1v2.csv'
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );

        SET @end_time = GETDATE();
        SET @batch_end_time = GETDATE();

        PRINT '>>>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_tme, @end_time) AS VARCHAR(50))
              + ' Seconds';

        PRINT '--------------------------------------------------------------------------------------------------------------------';

        /*=============================================================================================================
            COMPLETION MESSAGE
        =============================================================================================================*/

        PRINT '====================================================================================================================';
        PRINT 'Bronze Layer Loading Completed Successfully';
        PRINT 'Total Batch Duration: '
              + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS VARCHAR(20))
              + ' Seconds';
        PRINT '====================================================================================================================';

    END TRY

    BEGIN CATCH

        PRINT '=========================================================';
        PRINT 'ERROR OCCURRED DURING BRONZE LAYER LOAD';
        PRINT 'ERROR MESSAGE : ' + ERROR_MESSAGE();
        PRINT 'ERROR NUMBER  : ' + CAST(ERROR_NUMBER() AS VARCHAR(20));
        PRINT '=========================================================';

    END CATCH

END;
GO


/*=====================================================================================================================
    Usage Example
=====================================================================================================================*/

EXEC bronze.load_bronze;
GO


/*
===============================================================================
 Project     : Data Warehouse Initialization
 Author      : Kibreab Fiseha
 Description : This script creates the main Data Warehouse database and
               initializes the Medallion Architecture schemas:
               
               - bronze : Raw data ingestion layer
               - silver : Cleaned and transformed data layer
               - gold   : Business-ready analytics layer

 Workflow:
    CSV Files
        ↓
    Bronze Layer  (Raw Data)
        ↓
    Silver Layer  (Cleaned & Transformed Data)
        ↓
    Gold Layer    (Reporting & Analytics)
        ↓
    SQL Server Data Warehouse

     WARNING:
    ---------------------------------------------------------------------------
    This script will DROP and RECREATE the entire DatawareHouse database.

    All existing data, tables, stored procedures, views, functions,
    permissions, and schema objects inside the database will be permanently
    deleted.

    Make sure:
        - A backup exists before execution
        - No critical users are connected
        - The script is executed only in the correct environment

    Recommended for:
        - Development environments
        - Testing environments
        - Initial project setup
    ---------------------------------------------------------------------------

 Notes:
    - Existing database will be dropped and recreated.
    - SINGLE_USER mode is enabled before dropping the database
      to terminate active connections safely.
===============================================================================
*/

-- ============================================================================
-- Step 1: Drop Existing Database (If Exists)
-- ============================================================================

IF EXISTS (
    SELECT 1
    FROM sys.databases
    WHERE name = 'DatawareHouse'
)
BEGIN
    ALTER DATABASE DatawareHouse
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

    DROP DATABASE DatawareHouse;
END;
GO

-- ============================================================================
-- Step 2: Create New Data Warehouse Database
-- ============================================================================

CREATE DATABASE DatawareHouse;
GO

USE DatawareHouse;
GO

-- ============================================================================
-- Step 3: Create Bronze Schema
-- Raw Layer for CSV/Data Source Ingestion
-- ============================================================================

CREATE SCHEMA bronze;
GO

-- ============================================================================
-- Step 4: Create Silver Schema
-- Cleaned and Standardized Transformation Layer
-- ============================================================================

CREATE SCHEMA silver;
GO

-- ============================================================================
-- Step 5: Create Gold Schema
-- Business-Level Reporting and Analytics Layer
-- ============================================================================

CREATE SCHEMA gold;
GO

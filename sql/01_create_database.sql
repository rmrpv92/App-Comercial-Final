/* =====================================================================
   DB_APPCOMERCIAL - PART 1: CREATE DATABASE
   Version: 2.0
   Date: December 10, 2025
   
   Execute this script FIRST
   ===================================================================== */

USE master;
GO

-- Drop existing database if exists
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'DB_APPCOMERCIAL')
BEGIN
    ALTER DATABASE DB_APPCOMERCIAL SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DB_APPCOMERCIAL;
    PRINT '  Dropped existing database.';
END
GO

-- Create new database
CREATE DATABASE DB_APPCOMERCIAL;
GO

PRINT 'Database DB_APPCOMERCIAL created successfully.';
GO

USE DB_APPCOMERCIAL;
GO

PRINT 'Now run: 02_create_tables.sql';
GO

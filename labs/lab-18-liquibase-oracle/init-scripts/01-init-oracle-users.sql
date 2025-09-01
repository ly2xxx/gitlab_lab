-- Oracle Database Initialization Script for Liquibase Lab
-- This script creates necessary users and grants required privileges

-- Create application user for testing
CREATE USER app_user IDENTIFIED BY app_password
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

-- Grant basic privileges to application user
GRANT CONNECT, RESOURCE TO app_user;
GRANT CREATE SESSION TO app_user;
GRANT CREATE TABLE TO app_user;
GRANT CREATE VIEW TO app_user;
GRANT CREATE SEQUENCE TO app_user;
GRANT CREATE PROCEDURE TO app_user;
GRANT CREATE TRIGGER TO app_user;

-- Create additional tablespace for testing (if needed)
-- This is commented out as it requires DBA privileges which may not be available in XE
-- CREATE TABLESPACE liquibase_test
--   DATAFILE '/opt/oracle/oradata/XE/XEPDB1/liquibase_test01.dbf'
--   SIZE 100M
--   AUTOEXTEND ON
--   NEXT 10M
--   MAXSIZE 1G;

-- Ensure liquibase user has necessary privileges
GRANT CONNECT, RESOURCE, DBA TO liquibase;
GRANT CREATE SESSION TO liquibase;
GRANT CREATE TABLE TO liquibase;
GRANT CREATE VIEW TO liquibase;
GRANT CREATE SEQUENCE TO liquibase;
GRANT CREATE PROCEDURE TO liquibase;
GRANT CREATE TRIGGER TO liquibase;
GRANT CREATE MATERIALIZED VIEW TO liquibase;
GRANT CREATE TYPE TO liquibase;
GRANT CREATE SYNONYM TO liquibase;

-- Grant privileges to read system views (needed for Liquibase metadata queries)
GRANT SELECT ON DBA_TABLES TO liquibase;
GRANT SELECT ON DBA_TAB_COLUMNS TO liquibase;
GRANT SELECT ON DBA_CONSTRAINTS TO liquibase;
GRANT SELECT ON DBA_CONS_COLUMNS TO liquibase;
GRANT SELECT ON DBA_INDEXES TO liquibase;
GRANT SELECT ON DBA_IND_COLUMNS TO liquibase;
GRANT SELECT ON DBA_SEQUENCES TO liquibase;
GRANT SELECT ON DBA_TRIGGERS TO liquibase;

-- Alternative grants for non-DBA environments (use these if DBA views are not accessible)
GRANT SELECT ON USER_TABLES TO liquibase;
GRANT SELECT ON USER_TAB_COLUMNS TO liquibase;
GRANT SELECT ON USER_CONSTRAINTS TO liquibase;
GRANT SELECT ON USER_CONS_COLUMNS TO liquibase;
GRANT SELECT ON USER_INDEXES TO liquibase;
GRANT SELECT ON USER_IND_COLUMNS TO liquibase;
GRANT SELECT ON USER_SEQUENCES TO liquibase;
GRANT SELECT ON USER_TRIGGERS TO liquibase;

-- Grant privileges to access ALL_* views
GRANT SELECT ON ALL_TABLES TO liquibase;
GRANT SELECT ON ALL_TAB_COLUMNS TO liquibase;
GRANT SELECT ON ALL_CONSTRAINTS TO liquibase;
GRANT SELECT ON ALL_CONS_COLUMNS TO liquibase;
GRANT SELECT ON ALL_INDEXES TO liquibase;
GRANT SELECT ON ALL_IND_COLUMNS TO liquibase;
GRANT SELECT ON ALL_SEQUENCES TO liquibase;
GRANT SELECT ON ALL_TRIGGERS TO liquibase;

-- Create a test schema for environment-specific testing
CREATE USER liquibase_test IDENTIFIED BY liquibase_test_password
  DEFAULT TABLESPACE USERS
  TEMPORARY TABLESPACE TEMP
  QUOTA UNLIMITED ON USERS;

GRANT CONNECT, RESOURCE TO liquibase_test;
GRANT CREATE SESSION TO liquibase_test;
GRANT CREATE TABLE TO liquibase_test;
GRANT CREATE VIEW TO liquibase_test;
GRANT CREATE SEQUENCE TO liquibase_test;
GRANT CREATE PROCEDURE TO liquibase_test;
GRANT CREATE TRIGGER TO liquibase_test;

-- Grant liquibase user access to test schema
GRANT ALL PRIVILEGES ON liquibase_test.* TO liquibase;

-- Commit the changes
COMMIT;

-- Display created users
SELECT username, default_tablespace, temporary_tablespace, created
FROM dba_users
WHERE username IN ('LIQUIBASE', 'APP_USER', 'LIQUIBASE_TEST')
ORDER BY created DESC;
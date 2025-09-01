# Lab 18: Liquibase Community Edition with Oracle Database in Docker

## Overview

This comprehensive lab demonstrates advanced database schema management and migration using Liquibase Community Edition with Oracle Database 21c Express Edition running in Docker. The lab showcases Oracle-specific features including PL/SQL procedures, packages, sequences, triggers, materialized views, and advanced indexing strategies while integrating with GitLab CI/CD for enterprise-grade database deployment automation.

## Learning Objectives

By completing this lab, you will master:

- **Oracle Database Integration**: Setting up Liquibase with Oracle 21c XE in containerized environments
- **Advanced Oracle Features**: Implementing sequences, triggers, PL/SQL procedures, packages, and materialized views
- **Enterprise Schema Management**: Complex database schema versioning with Oracle-specific patterns
- **Multi-Environment Deployments**: Development, test, and production environment configurations
- **Oracle Performance Optimization**: Advanced indexing, function-based indexes, and query optimization
- **PL/SQL Development**: Creating stored procedures, functions, packages, and complex business logic
- **Oracle Security**: Role-based access control, audit trails, and session management
- **Automated Testing**: Oracle-specific test suites and performance benchmarking
- **CI/CD Integration**: GitLab pipelines optimized for Oracle database deployments
- **Oracle Troubleshooting**: Connection management, driver configuration, and debugging techniques

## Prerequisites

- Docker and Docker Compose (latest versions)
- 8GB+ RAM (Oracle Database is memory-intensive)
- 20GB+ disk space for Oracle container and data
- Basic understanding of SQL and Oracle PL/SQL
- Familiarity with Git, GitLab, and CI/CD concepts
- Understanding of enterprise database management practices

## Lab Structure

```
labs/lab-18-liquibase-oracle/
├── README.md                           # This comprehensive guide
├── .gitlab-ci.yml                      # Oracle-optimized GitLab CI/CD pipeline
├── docker-compose.yml                  # Oracle Database + Liquibase services
├── Dockerfile.liquibase                # Custom Liquibase image with Oracle drivers
├── liquibase.properties               # Oracle-specific Liquibase configuration
├── changelog/                          # Oracle database changelog files
│   ├── db-changelog-master.xml        # Master changelog orchestrator
│   ├── v1.0/                         # Version 1.0 - Foundation
│   │   ├── 01-initial-schema.xml      # Oracle tables, sequences, triggers
│   │   ├── 02-seed-data.xml           # Sample data with Oracle functions
│   │   └── data/                      # CSV data files for bulk loading
│   │       └── additional-products.csv
│   ├── v1.1/                         # Version 1.1 - RBAC & Audit
│   │   ├── 01-add-user-roles.xml      # Role-based access control
│   │   └── 02-add-audit-fields.xml    # Comprehensive audit trail with JSON
│   ├── v1.2/                         # Version 1.2 - Advanced Features
│   │   ├── 01-advanced-oracle-features.xml  # PL/SQL packages, materialized views
│   │   └── 02-performance-indexes.xml       # Advanced indexing strategies
│   └── environments/                  # Environment-specific configurations
│       ├── dev-specific.xml           # Development tools and test data generators
│       └── test-specific.xml          # Automated testing and validation procedures
├── scripts/                           # Oracle management utilities
│   └── manage-lab.sh                  # Comprehensive lab management script
└── init-scripts/                     # Oracle initialization scripts
    └── 01-init-oracle-users.sql      # User creation and privilege setup
```

## Quick Start

### 1. Environment Setup

```bash
# Clone and navigate to the lab
cd labs/lab-18-liquibase-oracle

# Make management script executable
chmod +x scripts/manage-lab.sh

# Initialize the Oracle environment (takes 5-10 minutes)
./scripts/manage-lab.sh setup
```

### 2. Verify Installation

```bash
# Test Oracle connection
./scripts/manage-lab.sh test-connection

# Check Liquibase status
./scripts/manage-lab.sh status

# Validate changelog files
./scripts/manage-lab.sh validate
```

### 3. Apply Database Changes

```bash
# Deploy to development environment
./scripts/manage-lab.sh update -c development

# View deployment history
./scripts/manage-lab.sh history

# Connect to Oracle SQL*Plus
./scripts/manage-lab.sh oracle-cli
```

## Oracle Database Architecture

### Database Schema Overview

The lab implements a comprehensive e-commerce system showcasing Oracle's enterprise features:

```
📊 Core Business Tables
├── users (with Oracle sequences & triggers)
├── products (with CLOB descriptions & categories)
├── orders (with complex constraints & status management)
└── order_items (with calculated totals & inventory updates)

🔐 Security & Access Control
├── roles (hierarchical role management)
├── permissions (granular access control)
├── user_roles (many-to-many relationships)
└── role_permissions (permission inheritance)

📋 Audit & Monitoring
├── audit_log (JSON-based change tracking)
├── user_sessions (session lifecycle management)
└── debug_log (development debugging tools)

🏗️ Oracle Advanced Features
├── product_categories (hierarchical data with Connect By)
├── mv_order_summary (materialized views for performance)
├── order_management package (PL/SQL business logic)
└── Custom types & table functions
```

### Oracle-Specific Features Demonstrated

1. **Sequences & Triggers**: Auto-incrementing primary keys with Oracle sequences
2. **PL/SQL Procedures**: Business logic implementation with stored procedures
3. **PL/SQL Packages**: Modular code organization with package specifications and bodies
4. **Triggers**: Data validation, audit trails, and automatic field updates
5. **Materialized Views**: Performance optimization for complex reporting queries
6. **Hierarchical Queries**: Product categories with Connect By relationships
7. **JSON Storage**: Modern data storage with Oracle's JSON capabilities
8. **Advanced Constraints**: Check constraints, composite keys, and referential integrity
9. **Function-based Indexes**: Case-insensitive searches and computed column indexes
10. **Object Types**: Custom types and pipelined table functions

## Management Script Usage

The `manage-lab.sh` script provides comprehensive Oracle database management:

### Basic Operations
```bash
./scripts/manage-lab.sh setup          # Initialize environment
./scripts/manage-lab.sh start          # Start all services
./scripts/manage-lab.sh stop           # Stop all services
./scripts/manage-lab.sh restart        # Restart services
./scripts/manage-lab.sh clean          # Remove containers and volumes
```

### Liquibase Operations
```bash
./scripts/manage-lab.sh status         # Show current database status
./scripts/manage-lab.sh update         # Apply all pending changes
./scripts/manage-lab.sh validate       # Validate changelog syntax
./scripts/manage-lab.sh history        # View deployment history
./scripts/manage-lab.sh generate-sql   # Generate SQL without applying
```

### Context-Specific Deployments
```bash
./scripts/manage-lab.sh update -c development    # Development environment
./scripts/manage-lab.sh update -c test          # Test environment
./scripts/manage-lab.sh update -c production    # Production environment
```

### Rollback Operations
```bash
./scripts/manage-lab.sh rollback -n 3           # Rollback 3 changesets
./scripts/manage-lab.sh rollback -t "v1.1"      # Rollback to tag
```

### Oracle-Specific Commands
```bash
./scripts/manage-lab.sh oracle-cli              # Oracle SQL*Plus interface
./scripts/manage-lab.sh test-connection         # Verify Oracle connectivity
./scripts/manage-lab.sh run-tests              # Execute test suite
./scripts/manage-lab.sh benchmark              # Performance benchmarks
```

## Docker Services

### Oracle Database 21c Express Edition
- **Image**: `gvenzl/oracle-xe:21c-slim`
- **Ports**: 1521 (Database), 5500 (Enterprise Manager)
- **Users**: `liquibase`, `app_user`, environment-specific users
- **Features**: Full Oracle 21c feature set optimized for development

### Custom Liquibase Container
- **Base**: `liquibase/liquibase:4.29.2`
- **Oracle JDBC**: Latest ojdbc11.jar and security libraries
- **Extensions**: Oracle-specific tools and utilities

## Environment Configurations

### Development Environment (`development` context)
- **Purpose**: Active development and feature testing
- **Features**: 
  - Debug logging table for troubleshooting
  - Test data generators for load testing
  - Development-specific procedures and views
  - Relaxed constraints for experimentation

### Test Environment (`test` context)  
- **Purpose**: Automated testing and validation
- **Features**:
  - Comprehensive test data validation procedures
  - Assertion functions for automated testing
  - Performance benchmarking procedures
  - Data integrity validation routines

### Production Environment (`production` context)
- **Purpose**: Production-ready deployment simulation
- **Features**:
  - Restricted permissions and security hardening
  - Performance-optimized indexes and statistics
  - Audit trail enforcement
  - Rollback safety procedures

## Oracle PL/SQL Examples

### Business Logic Package
```sql
-- Order Management Package
CREATE OR REPLACE PACKAGE order_management AS
    PROCEDURE create_order(
        p_user_id IN NUMBER,
        p_order_number IN VARCHAR2,
        p_order_id OUT NUMBER
    );
    
    FUNCTION get_order_status(
        p_order_id IN NUMBER
    ) RETURN VARCHAR2;
    
    PROCEDURE update_order_status(
        p_order_id IN NUMBER,
        p_new_status IN VARCHAR2
    );
END order_management;
```

### Audit Trail Trigger
```sql
-- Automatic audit logging with JSON
CREATE OR REPLACE TRIGGER products_audit_trg
AFTER INSERT OR UPDATE OR DELETE ON products
FOR EACH ROW
DECLARE
    v_operation VARCHAR2(10);
    v_old_values CLOB;
    v_new_values CLOB;
BEGIN
    IF INSERTING THEN
        v_operation := 'INSERT';
        v_new_values := JSON_OBJECT(
            'id' VALUE :NEW.id,
            'name' VALUE :NEW.name,
            'price' VALUE :NEW.price
        );
    -- Additional logic for UPDATE and DELETE
    END IF;
    
    INSERT INTO audit_log (table_name, operation, old_values, new_values)
    VALUES ('PRODUCTS', v_operation, v_old_values, v_new_values);
END;
```

### Hierarchical Category Query
```sql
-- Oracle Connect By for hierarchical data
SELECT 
    LEVEL,
    LPAD(' ', (LEVEL-1)*2, ' ') || name AS category_hierarchy,
    category_path
FROM product_categories
START WITH parent_category_id IS NULL
CONNECT BY PRIOR id = parent_category_id
ORDER SIBLINGS BY sort_order;
```

## Performance Features

### Advanced Indexing Strategies
- **Function-based indexes** for case-insensitive searches
- **Composite indexes** optimized for common query patterns  
- **Partial indexes** for filtered data subsets
- **Oracle hints** in complex views for query optimization

### Materialized Views
```sql
CREATE MATERIALIZED VIEW mv_order_summary
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT 
    o.id,
    o.order_number,
    get_user_full_name(o.user_id) AS customer_name,
    o.total_amount,
    COUNT(oi.id) AS item_count
FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
GROUP BY o.id, o.order_number, o.user_id, o.total_amount;
```

### Performance Monitoring
- Automated statistics gathering with `DBMS_STATS`
- Performance benchmark procedures
- Query execution plan optimization
- Index effectiveness monitoring

## Testing Framework

### Automated Test Suite
The lab includes comprehensive Oracle-specific testing procedures:

```sql
-- Main test suite execution
EXEC run_test_suite();

-- Individual test components
EXEC validate_test_data_integrity();
EXEC create_standard_test_dataset();
EXEC benchmark_user_queries();
```

### Test Categories
1. **Data Integrity Tests**: Foreign key consistency, constraint validation
2. **Business Logic Tests**: PL/SQL procedure correctness, calculation accuracy
3. **Performance Tests**: Query response time benchmarking
4. **Security Tests**: Access control, privilege verification
5. **Oracle Feature Tests**: Sequence functionality, trigger execution

## GitLab CI/CD Pipeline

### Pipeline Stages
1. **Validate**: Changelog syntax and Oracle connectivity verification
2. **Test**: Status checks, SQL generation, and Oracle feature testing
3. **Deploy-Dev**: Development environment deployment with debug features
4. **Deploy-Test**: Test environment with comprehensive validation
5. **Deploy-Prod**: Production-like deployment with security hardening

### Oracle-Specific Features
- **Oracle JDBC Driver Management**: Automatic driver download and configuration
- **Multi-User Deployments**: Separate Oracle users for each environment
- **Oracle Health Checks**: Database readiness verification with extended timeouts
- **PL/SQL Testing**: Automated execution of Oracle stored procedures
- **Performance Benchmarking**: Integrated query performance testing
- **Security Validation**: Oracle privilege and constraint verification

### Manual Deployment Gates
- Production deployments require manual approval
- Rollback procedures available for each environment
- Comprehensive pre-deployment validation
- Post-deployment verification with Oracle-specific queries

## Troubleshooting Guide

### Common Oracle Issues

#### Oracle Container Startup Problems
```bash
# Check Oracle container logs
./scripts/manage-lab.sh logs oracle

# Verify Oracle memory allocation (requires 2GB+)
docker stats oracle-server

# Check Oracle listener status
./scripts/manage-lab.sh oracle-cli
SQL> SELECT * FROM v$listener_network;
```

#### Oracle Connection Issues
```bash
# Test basic connectivity
./scripts/manage-lab.sh test-connection

# Verify Oracle service status
docker-compose -f docker-compose.yml exec oracle lsnrctl status

# Check Oracle processes
docker-compose -f docker-compose.yml exec oracle ps -ef | grep oracle
```

#### Liquibase Oracle Driver Issues
```bash
# Verify JDBC driver availability
docker-compose -f docker-compose.yml run --rm liquibase ls -la /liquibase/lib/ojdbc*

# Test Liquibase Oracle connectivity
docker-compose -f docker-compose.yml run --rm liquibase validate
```

### Performance Optimization

#### Oracle Memory Configuration
- Increase Docker memory allocation to 4GB+ for production workloads
- Monitor Oracle SGA and PGA usage with `v$sga` and `v$pgastat`

#### Query Performance Tuning
```sql
-- Enable Oracle autotrace for query analysis
SET AUTOTRACE ON EXPLAIN STATISTICS;

-- Analyze slow queries
SELECT sql_text, executions, elapsed_time 
FROM v$sql 
WHERE elapsed_time > 1000000
ORDER BY elapsed_time DESC;
```

## Enterprise Extensions

### Production Deployment Considerations
1. **Oracle Enterprise Edition**: Upgrade to Oracle EE for production features
2. **RAC Configuration**: Real Application Clusters for high availability  
3. **Data Guard**: Disaster recovery and standby database setup
4. **Oracle Security**: Advanced Security Option, Transparent Data Encryption
5. **Monitoring Integration**: Oracle Enterprise Manager, AWR reports

### Advanced Oracle Features
- **Partitioning**: Table and index partitioning for large datasets
- **Parallel Processing**: Parallel DML and query execution
- **Advanced Compression**: Table and index compression
- **In-Memory Option**: Oracle Database In-Memory column store
- **Multitenant Architecture**: Container databases and pluggable databases

## Learning Resources

### Oracle Documentation
- [Oracle Database 21c Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/21/)
- [PL/SQL Language Reference](https://docs.oracle.com/en/database/oracle/oracle-database/21/lnpls/)
- [Oracle SQL Developer Guide](https://docs.oracle.com/en/database/oracle/sql-developer/)

### Liquibase Oracle Integration
- [Liquibase Oracle Database Tutorial](https://docs.liquibase.com/start/tutorials/oracle.html)
- [Oracle-Specific Change Types](https://docs.liquibase.com/change-types/oracle/)
- [Oracle JDBC Driver Configuration](https://docs.liquibase.com/workflows/liquibase-community/adding-and-updating-liquibase-drivers.html)

## Best Practices

### Oracle Development
1. **Use sequences instead of identity columns** for maximum compatibility
2. **Implement comprehensive error handling** in PL/SQL procedures
3. **Design for performance** with proper indexing strategies
4. **Leverage Oracle's advanced features** like materialized views and partitioning
5. **Follow Oracle naming conventions** for database objects

### Liquibase with Oracle
1. **Use Oracle-specific data types** (VARCHAR2, NUMBER, CLOB, etc.)
2. **Test rollback procedures** thoroughly for all changesets
3. **Validate Oracle syntax** before deploying to production
4. **Use contexts effectively** for environment-specific changes
5. **Monitor Oracle-specific metrics** during deployments

### DevOps Integration
1. **Automate Oracle statistics gathering** after major deployments
2. **Implement comprehensive logging** for troubleshooting
3. **Use Oracle health checks** in CI/CD pipelines
4. **Plan for Oracle-specific backup strategies**
5. **Monitor Oracle performance metrics** continuously

## Support and Maintenance

### Regular Maintenance Tasks
```bash
# Weekly maintenance routine
./scripts/manage-lab.sh oracle-cli
SQL> EXEC DBMS_STATS.GATHER_SCHEMA_STATS(USER);
SQL> EXEC cleanup_expired_sessions();

# Monthly maintenance
SQL> EXEC archive_old_audit_logs(90);
SQL> EXEC analyze_table_performance('PRODUCTS');
```

### Monitoring and Alerts
- Set up Oracle Enterprise Manager for comprehensive monitoring
- Configure alerts for tablespace usage, session limits, and performance metrics
- Monitor Liquibase deployment success rates and execution times

## Conclusion

This lab provides a comprehensive foundation for enterprise Oracle database management with Liquibase, demonstrating advanced Oracle features, robust CI/CD integration, and production-ready deployment practices. The combination of Oracle's enterprise capabilities with Liquibase's change management provides a powerful platform for modern database DevOps practices.

The skills and patterns learned in this lab are directly applicable to enterprise Oracle environments, providing a solid foundation for database reliability engineering, automated deployment pipelines, and Oracle-specific performance optimization strategies.
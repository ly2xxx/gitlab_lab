# Lab 17: Liquibase Community Edition with MySQL in Docker

## Overview

This comprehensive lab demonstrates database schema management and migration using Liquibase Community Edition with a MySQL database running in Docker. The lab covers common Liquibase use scenarios including schema creation, data seeding, rollback scenarios, environment-specific configurations, and GitLab CI/CD integration.

## Learning Objectives

By completing this lab, you will learn:

- How to set up Liquibase Community Edition with MySQL in Docker
- Database schema versioning and migration strategies
- Creating and managing database changelogs
- Implementing rollback strategies and safety measures
- Environment-specific database configurations
- Automated database deployments with GitLab CI/CD
- Database testing and validation techniques
- Advanced Liquibase features and best practices

## Prerequisites

- Docker and Docker Compose installed
- Basic understanding of SQL and database concepts
- Familiarity with Git and GitLab
- Basic understanding of CI/CD concepts

## Lab Structure

```
labs/lab-17-liquibase-mysql/
├── docker-compose.yml              # Docker services configuration
├── liquibase.properties            # Liquibase configuration
├── .gitlab-ci.yml                  # GitLab CI/CD pipeline
├── changelog/                      # Database changelog files
│   ├── db-changelog-master.xml     # Master changelog file
│   ├── v1.0/                      # Version 1.0 changes
│   │   ├── 01-initial-schema.xml   # Initial database schema
│   │   ├── 02-seed-data.xml        # Sample data insertion
│   │   └── data/                   # CSV data files
│   ├── v1.1/                      # Version 1.1 changes
│   │   ├── 01-add-user-roles.xml   # User roles and permissions
│   │   └── 02-add-audit-fields.xml # Audit trail implementation
│   ├── v1.2/                      # Version 1.2 changes
│   │   ├── 01-advanced-features.xml # Advanced database features
│   │   └── 02-performance-indexes.xml # Performance optimizations
│   └── environments/              # Environment-specific changes
│       ├── dev-specific.xml        # Development environment
│       └── test-specific.xml       # Test environment
├── scripts/                       # Utility scripts
│   └── manage-lab.sh              # Lab management script
├── init-scripts/                  # MySQL initialization
│   └── 01-init-databases.sh       # Database setup script
└── README.md                      # This documentation
```

## Quick Start

### 1. Clone and Navigate

```bash
git clone <repository-url>
cd labs/lab-17-liquibase-mysql
```

### 2. Make Scripts Executable

```bash
chmod +x scripts/manage-lab.sh
chmod +x init-scripts/01-init-databases.sh
```

### 3. Set Up the Lab Environment

```bash
./scripts/manage-lab.sh setup
```

This command will:
- Start the MySQL and Liquibase containers
- Wait for MySQL to be ready
- Validate the Liquibase configuration
- Prepare the environment for database migrations

### 4. Apply Initial Database Changes

```bash
./scripts/manage-lab.sh update
```

### 5. Verify the Setup

```bash
./scripts/manage-lab.sh status
```

## Detailed Usage Guide

### Available Management Commands

The `manage-lab.sh` script provides comprehensive lab management:

```bash
# Environment Management
./scripts/manage-lab.sh setup           # Initialize lab environment
./scripts/manage-lab.sh start           # Start containers
./scripts/manage-lab.sh stop            # Stop containers
./scripts/manage-lab.sh restart         # Restart containers
./scripts/manage-lab.sh clean           # Clean up everything

# Database Operations  
./scripts/manage-lab.sh status          # Show current status
./scripts/manage-lab.sh update          # Apply pending changes
./scripts/manage-lab.sh history         # Show changelog history
./scripts/manage-lab.sh validate        # Validate changelog files

# Rollback Operations
./scripts/manage-lab.sh rollback -n 3   # Rollback 3 changesets
./scripts/manage-lab.sh rollback -t v1.0 # Rollback to tag

# SQL Generation
./scripts/manage-lab.sh generate-sql    # Generate SQL for changes
./scripts/manage-lab.sh generate-sql > changes.sql # Save to file

# Database Access
./scripts/manage-lab.sh shell           # Open MySQL shell
./scripts/manage-lab.sh logs            # View container logs

# Testing and Maintenance
./scripts/manage-lab.sh test            # Run database tests
./scripts/manage-lab.sh reset           # Reset to clean state
./scripts/manage-lab.sh backup          # Create database backup
./scripts/manage-lab.sh restore backup.sql # Restore from backup
```

### Environment Contexts

The lab supports different environments through Liquibase contexts:

- **development**: Includes development-specific data and utilities
- **test**: Includes test data and validation procedures
- **production**: Production-ready schema without test data

```bash
# Apply changes for specific environment
./scripts/manage-lab.sh update -c development
./scripts/manage-lab.sh update -c test  
./scripts/manage-lab.sh update -c production
```

## Lab Exercises

### Exercise 1: Basic Schema Creation

1. **Examine the Initial Schema**
   ```bash
   ./scripts/manage-lab.sh status
   cat changelog/v1.0/01-initial-schema.xml
   ```

2. **Apply the Schema**
   ```bash
   ./scripts/manage-lab.sh update -c development
   ```

3. **Verify Tables Created**
   ```bash
   ./scripts/manage-lab.sh shell
   SHOW TABLES;
   DESCRIBE users;
   DESCRIBE products;
   DESCRIBE orders;
   ```

### Exercise 2: Data Seeding and Management

1. **Review Seed Data Configuration**
   ```bash
   cat changelog/v1.0/02-seed-data.xml
   ```

2. **Load Sample Data**
   ```bash
   ./scripts/manage-lab.sh update -c development
   ```

3. **Query the Seeded Data**
   ```bash
   ./scripts/manage-lab.sh shell
   SELECT * FROM users;
   SELECT * FROM products LIMIT 5;
   SELECT COUNT(*) FROM orders;
   ```

### Exercise 3: Schema Evolution

1. **Add User Roles System**
   ```bash
   cat changelog/v1.1/01-add-user-roles.xml
   ./scripts/manage-lab.sh update -c development
   ```

2. **Verify New Tables**
   ```bash
   ./scripts/manage-lab.sh shell
   SHOW TABLES LIKE '%role%';
   SELECT r.name, COUNT(ur.user_id) as user_count 
   FROM roles r 
   LEFT JOIN user_roles ur ON r.id = ur.role_id 
   GROUP BY r.id, r.name;
   ```

### Exercise 4: Audit Trail Implementation

1. **Add Audit Fields**
   ```bash
   ./scripts/manage-lab.sh update -c development
   ```

2. **Test Audit Triggers**
   ```bash
   ./scripts/manage-lab.sh shell
   UPDATE products SET price = 999.99 WHERE sku = 'LAP-PRO-15-001';
   SELECT * FROM audit_log ORDER BY created_at DESC LIMIT 5;
   ```

### Exercise 5: Advanced Features

1. **Explore Advanced Features**
   ```bash
   cat changelog/v1.2/01-advanced-features.xml
   ./scripts/manage-lab.sh update -c development
   ```

2. **Test Stored Procedures**
   ```bash
   ./scripts/manage-lab.sh shell
   CALL GetUserOrderSummary(1, '2024-01-01', '2024-12-31');
   CALL UpdateProductPrice(1, 1499.99, 1, 'Price adjustment for market conditions');
   ```

### Exercise 6: Performance Optimization

1. **Apply Performance Indexes**
   ```bash
   ./scripts/manage-lab.sh update -c development
   ```

2. **Analyze Index Usage**
   ```bash
   ./scripts/manage-lab.sh shell
   SELECT * FROM index_usage_stats WHERE table_name = 'products';
   EXPLAIN SELECT * FROM products WHERE category_id = 1 AND is_active = 1;
   ```

### Exercise 7: Environment-Specific Deployments

1. **Deploy to Test Environment**
   ```bash
   ./scripts/manage-lab.sh update -c test
   ```

2. **Verify Test-Specific Data**
   ```bash
   ./scripts/manage-lab.sh shell
   SELECT * FROM users WHERE username LIKE 'test%';
   SELECT * FROM test_validations;
   ```

### Exercise 8: Rollback Scenarios

1. **Generate Rollback SQL**
   ```bash
   ./scripts/manage-lab.sh shell
   ```
   ```sql
   -- In MySQL shell
   SELECT * FROM DATABASECHANGELOG ORDER BY DATEEXECUTED DESC LIMIT 5;
   ```

2. **Perform Rollback**
   ```bash
   ./scripts/manage-lab.sh rollback -n 2
   ./scripts/manage-lab.sh status
   ```

3. **Re-apply Changes**
   ```bash
   ./scripts/manage-lab.sh update -c development
   ```

### Exercise 9: Testing and Validation

1. **Run Database Tests**
   ```bash
   ./scripts/manage-lab.sh test
   ```

2. **Execute Test Procedures**
   ```bash
   ./scripts/manage-lab.sh shell
   CALL CleanupTestData();
   CALL ResetTestSequences();
   ```

### Exercise 10: Backup and Restore

1. **Create Backup**
   ```bash
   ./scripts/manage-lab.sh backup
   ls -la *.sql
   ```

2. **Reset and Restore**
   ```bash
   ./scripts/manage-lab.sh reset
   ./scripts/manage-lab.sh restore backup-YYYYMMDD-HHMMSS.sql
   ```

## GitLab CI/CD Integration

The lab includes a comprehensive GitLab CI/CD pipeline (`.gitlab-ci.yml`) with the following stages:

### Pipeline Stages

1. **Validate**: Syntax validation of changelog files
2. **Test**: Status checks and SQL generation
3. **Deploy-Dev**: Development environment deployment
4. **Deploy-Test**: Test environment deployment  
5. **Deploy-Prod**: Production simulation deployment

### Pipeline Features

- **Automatic validation** on merge requests
- **Multi-environment deployments** with manual approval
- **Rollback capabilities** for each environment
- **Artifact generation** for SQL scripts and reports
- **Database documentation** generation

### Running in GitLab

1. **Push to Feature Branch**
   ```bash
   git checkout -b feature/database-changes
   # Make changes to changelog files
   git add .
   git commit -m "Add new database features"
   git push origin feature/database-changes
   ```

2. **Create Merge Request**
   - Pipeline automatically validates changes
   - Review generated SQL in artifacts
   - Manual approval required for deployments

3. **Deploy to Environments**
   - Development: Automatic or manual
   - Test: Manual approval required
   - Production: Manual approval after test success

## Database Schema Overview

### Core Tables

- **users**: User accounts and authentication
- **roles**: Role-based access control
- **user_roles**: User-role assignments  
- **permissions**: Granular permissions
- **role_permissions**: Role-permission mappings
- **products**: Product catalog
- **categories**: Hierarchical product categories
- **product_variants**: Product variations and attributes
- **orders**: Customer orders
- **order_items**: Order line items
- **shopping_carts**: Shopping cart functionality
- **user_sessions**: Session management
- **audit_log**: Comprehensive audit trail

### Advanced Features

- **Hierarchical Categories**: Self-referencing category tree
- **Product Variants**: Support for product options (color, size, etc.)
- **Audit Triggers**: Automatic change tracking
- **Stored Procedures**: Business logic in database
- **Views**: Simplified data access
- **Full-text Search**: MySQL full-text indexes
- **Soft Deletes**: Logical deletion with timestamps
- **JSON Attributes**: Modern data storage

## Troubleshooting

### Common Issues

1. **MySQL Not Starting**
   ```bash
   docker-compose logs mysql
   ./scripts/manage-lab.sh restart
   ```

2. **Liquibase Connection Errors**
   ```bash
   # Check if MySQL is ready
   docker-compose exec mysql mysql -u liquibase -pliquibase_password -e "SELECT 1"
   
   # Verify network connectivity
   docker-compose exec liquibase ping mysql
   ```

3. **Permission Issues**
   ```bash
   chmod +x scripts/manage-lab.sh
   chmod +x init-scripts/01-init-databases.sh
   ```

4. **Port Conflicts**
   ```bash
   # Check if port 3306 is in use
   lsof -i :3306
   
   # Modify docker-compose.yml to use different port
   ports:
     - "3307:3306"
   ```

### Logs and Debugging

```bash
# View all container logs
./scripts/manage-lab.sh logs

# View specific service logs
docker-compose logs mysql
docker-compose logs liquibase

# Enable Liquibase debug logging
# Edit liquibase.properties and set:
# logLevel=DEBUG
```

## Best Practices Demonstrated

### Changelog Organization
- **Modular structure** with separate files for different features
- **Version-based organization** for clear progression
- **Environment-specific changes** with appropriate contexts
- **Comprehensive rollback strategies**

### Database Design
- **Proper foreign key relationships**
- **Appropriate indexing strategies**
- **Audit trail implementation**
- **Soft delete patterns**
- **JSON for flexible attributes**

### DevOps Integration
- **Automated validation** in CI/CD
- **Multi-environment support**
- **Artifact generation** for review
- **Backup and restore procedures**

### Testing Strategies
- **Test data management**
- **Constraint validation**
- **Procedure testing**
- **Environment isolation**

## Advanced Topics

### Custom Change Types
The lab demonstrates several advanced Liquibase features:
- Custom SQL with stored procedures
- Conditional changes with preconditions
- Data loading from CSV files
- Database-specific optimizations

### Performance Considerations
- Composite indexes for common queries
- Full-text search capabilities
- Table partitioning examples
- Query optimization techniques

### Security Features
- Role-based access control (RBAC)
- Audit logging for compliance
- Session management
- Data encryption considerations

## Extensions and Customizations

### Adding New Features

1. **Create New Changelog File**
   ```bash
   # Create new version directory
   mkdir changelog/v1.3
   
   # Add new changelog
   touch changelog/v1.3/01-new-feature.xml
   
   # Update master changelog
   # Add include directive in db-changelog-master.xml
   ```

2. **Test Changes**
   ```bash
   ./scripts/manage-lab.sh validate
   ./scripts/manage-lab.sh generate-sql
   ./scripts/manage-lab.sh update -c development
   ```

### Environment Customization

Modify environment-specific files to add:
- Additional seed data
- Environment-specific indexes
- Custom validation procedures
- Performance monitoring

## Cleanup

To completely remove the lab environment:

```bash
./scripts/manage-lab.sh clean
docker system prune -a -f --volumes
```

## Conclusion

This lab provides a comprehensive introduction to database schema management with Liquibase and MySQL. It demonstrates industry best practices for database versioning, automated deployments, and DevOps integration.

The skills learned in this lab are directly applicable to real-world database management scenarios, making it an excellent foundation for database DevOps practices.

## Additional Resources

- [Liquibase Documentation](https://docs.liquibase.com/)
- [MySQL Documentation](https://dev.mysql.com/doc/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Database Migration Best Practices](https://martinfowler.com/articles/evodb.html)

---

**Happy Learning!** 🚀

For questions or issues, please refer to the troubleshooting section or create an issue in the repository.

# Lab 18: Liquibase Database Migrations with Microsoft SQL Server

**Duration**: 120 minutes  
**Difficulty**: Advanced  
**Prerequisites**: Labs 0-4, Docker knowledge, SQL Server basics

## 🎯 Learning Objectives

By the end of this lab, you will:
- Set up Microsoft SQL Server 2019 Developer Edition in Docker
- Configure Liquibase for database schema management
- Implement automated database migrations in GitLab CI/CD
- Handle database versioning, rollbacks, and environment promotion
- Integrate database changes with application deployment pipelines
- Implement database testing and validation strategies

## 📋 Prerequisites

### Technical Requirements
- GitLab account with CI/CD enabled
- Docker Desktop installed and running
- Git client configured
- Basic SQL Server and database migration knowledge
- Completed Lab 0 (GitLab setup) and Lab 4 (Docker integration)

### System Requirements
- **Memory**: 4GB+ available for SQL Server container
- **Storage**: 2GB+ free disk space
- **Network**: Internet access for downloading images and dependencies

## 🏗️ Architecture Overview

This lab demonstrates:
```
┌─────────────────────────────────────────────────────────────┐
│                    GitLab CI/CD Pipeline                    │
├─────────────────────────────────────────────────────────────┤
│ Validate → Build → Test → Deploy DB → Test DB → Deploy App │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Database Environments                     │
├─────────────────────────────────────────────────────────────┤
│  Development  →  Staging  →  Production                     │
│  (Auto-deploy)   (Manual)     (Manual + Approval)          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    SQL Server Instances                     │
├─────────────────────────────────────────────────────────────┤
│  • Schema versioning with Liquibase                        │
│  • Automated rollback capabilities                         │
│  • Environment-specific configurations                      │
│  • Data seeding and test data management                   │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Lab Setup

### Step 1: Repository Setup

1. **Navigate to the lab directory:**
```bash
cd labs/lab-18-liquibase-mssql
```

2. **Verify directory structure:**
```bash
tree .
# Expected structure:
# .
# ├── README.md
# ├── .gitlab-ci.yml
# ├── docker-compose.yml
# ├── liquibase/
# │   ├── liquibase.properties
# │   ├── changelogs/
# │   └── sql/
# ├── config/
# ├── scripts/
# ├── src/
# └── tests/
```

### Step 2: Local Environment Setup

1. **Start SQL Server container:**
```bash
# Make setup script executable
chmod +x scripts/setup-environment.sh

# Run setup (creates containers, databases, and initial configuration)
./scripts/setup-environment.sh
```

2. **Verify SQL Server is running:**
```bash
# Check container status
docker ps | grep sqlserver

# Test connection
docker exec -it lab18-sqlserver /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong@Passw0rd123" \
  -Q "SELECT @@VERSION"
```

3. **Initialize Liquibase:**
```bash
# Run initial Liquibase setup
./scripts/init-liquibase.sh
```

## 📚 Core Concepts

### Liquibase Fundamentals

**Changelog Structure:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
    http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.20.xsd">

    <changeSet id="001" author="developer">
        <createTable tableName="users">
            <column name="id" type="int" autoIncrement="true">
                <constraints primaryKey="true"/>
            </column>
            <column name="username" type="varchar(50)">
                <constraints nullable="false" unique="true"/>
            </column>
            <column name="email" type="varchar(100)">
                <constraints nullable="false"/>
            </column>
            <column name="created_at" type="datetime" defaultValueComputed="GETDATE()"/>
        </createTable>
    </changeSet>
</databaseChangeLog>
```

**Key Concepts:**
- **ChangeSet**: Atomic unit of database change
- **Changelog**: Collection of changesets
- **Rollback**: Ability to undo changes
- **Contexts**: Environment-specific changes
- **Labels**: Grouping and filtering changes

## 🔧 Hands-on Exercises

### Exercise 1: Basic Schema Creation

1. **Create your first changelog:**
```bash
# Edit the master changelog
nano liquibase/changelogs/db.changelog-master.xml
```

2. **Add initial schema:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
    http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.20.xsd">

    <include file="changelogs/001-initial-schema.xml" relativeToChangelogFile="true"/>
    <include file="changelogs/002-add-products.xml" relativeToChangelogFile="true"/>
    <include file="changelogs/003-add-orders.xml" relativeToChangelogFile="true"/>
</databaseChangeLog>
```

3. **Test locally:**
```bash
# Run Liquibase update
./scripts/liquibase-update.sh development

# Verify changes
./scripts/validate-schema.sh development
```

### Exercise 2: Environment-Specific Migrations

1. **Create environment-specific changes:**
```xml
<!-- In 002-add-products.xml -->
<changeSet id="002-1" author="developer">
    <createTable tableName="products">
        <column name="id" type="int" autoIncrement="true">
            <constraints primaryKey="true"/>
        </column>
        <column name="name" type="varchar(100)">
            <constraints nullable="false"/>
        </column>
        <column name="price" type="decimal(10,2)">
            <constraints nullable="false"/>
        </column>
    </createTable>
</changeSet>

<!-- Development test data -->
<changeSet id="002-2" author="developer" context="development,testing">
    <insert tableName="products">
        <column name="name" value="Test Product 1"/>
        <column name="price" value="19.99"/>
    </insert>
    <insert tableName="products">
        <column name="name" value="Test Product 2"/>
        <column name="price" value="29.99"/>
    </insert>
</changeSet>
```

2. **Test with contexts:**
```bash
# Development with test data
./scripts/liquibase-update.sh development

# Production without test data
./scripts/liquibase-update.sh production
```

### Exercise 3: GitLab CI/CD Integration

1. **Commit your changes:**
```bash
git add .
git commit -m "Add initial database schema"
git push origin main
```

2. **Monitor pipeline:**
- Go to GitLab → CI/CD → Pipelines
- Watch the database migration stages execute
- Verify each environment deployment

3. **Test rollback:**
```bash
# Create a problematic changeset
# Then test rollback in pipeline
git add .
git commit -m "Test rollback scenario"
git push origin main
```

### Exercise 4: Advanced Migration Patterns

1. **Create complex migration:**
```xml
<changeSet id="004" author="developer">
    <!-- Add new column -->
    <addColumn tableName="users">
        <column name="status" type="varchar(20)" defaultValue="active">
            <constraints nullable="false"/>
        </column>
    </addColumn>
    
    <!-- Create index -->
    <createIndex tableName="users" indexName="idx_users_status">
        <column name="status"/>
    </createIndex>
    
    <!-- Add foreign key -->
    <addForeignKeyConstraint
        baseTableName="orders"
        baseColumnNames="user_id"
        referencedTableName="users"
        referencedColumnNames="id"
        constraintName="fk_orders_user"/>
</changeSet>
```

2. **Test migration performance:**
```bash
# Run with timing
./scripts/liquibase-update.sh staging --verbose

# Generate rollback SQL
./scripts/generate-rollback.sh staging 004
```

## 🧪 Testing and Validation

### Database Testing Strategy

1. **Schema validation tests:**
```bash
# Run schema tests
npm run test:schema

# Validate constraints
npm run test:constraints

# Test data integrity
npm run test:data-integrity
```

2. **Migration testing:**
```bash
# Test forward migration
./scripts/test-migration.sh forward

# Test rollback
./scripts/test-migration.sh rollback
```

3. **Performance testing:**
```bash
# Test migration performance
./scripts/test-performance.sh

# Generate performance report
./scripts/generate-performance-report.sh
```

## 🔒 Security and Best Practices

### Security Configuration

1. **Database credentials management:**
```yaml
# In .gitlab-ci.yml
variables:
  DB_HOST: ${DB_HOST}
  DB_USER: ${DB_USER}
  DB_PASSWORD: ${DB_PASSWORD}  # From GitLab CI/CD variables
```

2. **Network security:**
```yaml
# docker-compose.yml
services:
  sqlserver:
    networks:
      - db-network
    ports:
      - "127.0.0.1:1433:1433"  # Bind to localhost only
```

### Best Practices

1. **Changelog organization:**
   - One feature per changeset
   - Descriptive changeset IDs
   - Proper author attribution
   - Rollback instructions for complex changes

2. **Environment management:**
   - Use contexts for environment-specific data
   - Separate configuration per environment
   - Validate before production deployment

3. **Version control:**
   - Never modify existing changesets
   - Use semantic versioning for releases
   - Tag major schema versions

## 🚨 Troubleshooting

### Common Issues

**Issue**: SQL Server container won't start
```bash
# Check system resources
docker system df
free -h

# Check container logs
docker logs lab18-sqlserver

# Verify password complexity
# Password must be at least 8 characters with uppercase, lowercase, numbers, and symbols
```

**Issue**: Liquibase connection fails
```bash
# Test connection manually
docker exec -it lab18-sqlserver /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P "YourStrong@Passw0rd123" \
  -Q "SELECT 1"

# Check Liquibase properties
cat liquibase/liquibase.properties

# Verify JDBC driver
ls -la liquibase/lib/
```

**Issue**: Migration fails in pipeline
```bash
# Check pipeline logs
# Review changeset syntax
# Validate SQL Server compatibility

# Test locally first
./scripts/validate-changelog.sh
```

### Performance Optimization

1. **SQL Server configuration:**
```sql
-- Increase memory allocation
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'max server memory', 2048;  -- 2GB
RECONFIGURE;
```

2. **Liquibase optimization:**
```properties
# liquibase.properties
liquibase.hub.mode=off
liquibase.showSummary=SUMMARY
liquibase.showSummaryOutput=LOG
```

## 🎯 Success Criteria

By the end of this lab, you should have:

✅ **Environment Setup**
- [ ] SQL Server 2019 running in Docker
- [ ] Liquibase configured and operational
- [ ] GitLab CI/CD pipeline executing successfully

✅ **Database Migrations**
- [ ] Created initial schema with multiple tables
- [ ] Implemented environment-specific data seeding
- [ ] Successfully deployed to development environment
- [ ] Tested rollback capabilities

✅ **CI/CD Integration**
- [ ] Pipeline automatically runs migrations
- [ ] Different environments have appropriate configurations
- [ ] Manual approval gates for production
- [ ] Rollback procedures documented and tested

✅ **Advanced Features**
- [ ] Complex migrations with indexes and foreign keys
- [ ] Performance testing of migrations
- [ ] Security best practices implemented
- [ ] Comprehensive testing strategy

## 🔄 Next Steps

### Extend Your Knowledge

1. **Advanced Liquibase Features:**
   - Stored procedures and functions
   - Data transformations
   - Custom change types
   - Liquibase Hub integration

2. **Enterprise Patterns:**
   - Multi-tenant database schemas
   - Blue-green database deployments
   - Database branching strategies
   - Compliance and audit trails

3. **Integration Opportunities:**
   - Combine with Lab 11 (GitOps) for database GitOps
   - Integrate with Lab 6 (Security) for database security scanning
   - Connect with Lab 12 (Workflows) for complex deployment patterns

### Production Considerations

1. **Backup and Recovery:**
   - Automated backup strategies
   - Point-in-time recovery
   - Disaster recovery procedures

2. **Monitoring and Alerting:**
   - Database performance monitoring
   - Migration failure alerts
   - Schema drift detection

3. **Compliance:**
   - Change approval workflows
   - Audit trail maintenance
   - Regulatory compliance (GDPR, SOX, etc.)

## 📚 Additional Resources

### Documentation
- [Liquibase Documentation](https://docs.liquibase.com/)
- [SQL Server on Docker](https://docs.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker)
- [GitLab Database Review Guidelines](https://docs.gitlab.com/ee/development/database_review.html)

### Best Practices
- [Database Migration Best Practices](https://docs.liquibase.com/concepts/bestpractices.html)
- [SQL Server Best Practices](https://docs.microsoft.com/en-us/sql/relational-databases/best-practices)
- [GitLab CI/CD for Databases](https://docs.gitlab.com/ee/ci/examples/database_testing/)

### Community
- [Liquibase Community Forum](https://forum.liquibase.org/)
- [SQL Server Community](https://techcommunity.microsoft.com/t5/sql-server/ct-p/SQLServer)
- [GitLab Database Team](https://about.gitlab.com/handbook/engineering/development/enablement/database/)

---

**🎉 Congratulations!** You've successfully implemented enterprise-grade database migration management with Liquibase and SQL Server in GitLab CI/CD!

**Ready for more?** Try combining this lab with other advanced labs or implement it in your own projects.

---

*This lab is part of the comprehensive GitLab CI/CD tutorial series. Each lab builds upon previous concepts while introducing new advanced patterns.*
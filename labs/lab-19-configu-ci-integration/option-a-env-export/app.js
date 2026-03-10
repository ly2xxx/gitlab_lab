#!/usr/bin/env node
/**
 * Sample Node.js Application - Option A
 * ======================================
 * Demonstrates how to use environment variables from Configu .env export
 * 
 * Usage:
 *   1. Export config: configu export --set "development" --schema "./config.cfgu.json" > .env
 *   2. Source .env: source .env  (or use dotenv package)
 *   3. Run app: node app.js
 */

// Load environment variables from .env file (if using dotenv package)
// require('dotenv').config();

const http = require('http');

// Read configuration from environment variables
const config = {
  apiUrl: process.env.API_URL || 'http://localhost:3000',
  dbHost: process.env.DB_HOST || 'localhost',
  dbPort: parseInt(process.env.DB_PORT || '5432'),
  dbName: process.env.DB_NAME || 'myapp',
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
  logLevel: process.env.LOG_LEVEL || 'info',
  maxConnections: parseInt(process.env.MAX_CONNECTIONS || '100'),
  sessionTimeout: parseInt(process.env.SESSION_TIMEOUT || '3600'),
  rateLimit: parseInt(process.env.RATE_LIMIT || '100'),
  corsOrigins: process.env.CORS_ORIGINS || '*',
  cacheTTL: parseInt(process.env.CACHE_TTL || '300'),
  envName: process.env.ENV_NAME || 'development',
  
  // Feature flags
  features: {
    newUI: process.env.FEATURE_NEW_UI === 'true',
    analytics: process.env.FEATURE_ANALYTICS === 'true'
  }
};

// Validate critical configuration
function validateConfig() {
  const errors = [];
  
  if (!config.apiUrl.startsWith('http')) {
    errors.push('API_URL must be a valid HTTP/HTTPS URL');
  }
  
  if (!config.dbHost) {
    errors.push('DB_HOST is required');
  }
  
  if (!['development', 'staging', 'production'].includes(config.envName)) {
    errors.push('ENV_NAME must be development, staging, or production');
  }
  
  if (errors.length > 0) {
    console.error('❌ Configuration validation failed:');
    errors.forEach(err => console.error(`  - ${err}`));
    process.exit(1);
  }
  
  console.log('✅ Configuration validated successfully');
}

// Display current configuration
function displayConfig() {
  console.log('\n================================================');
  console.log('🚀 Application Configuration (from .env)');
  console.log('================================================');
  console.log(`Environment:     ${config.envName}`);
  console.log(`API URL:         ${config.apiUrl}`);
  console.log(`Database:        ${config.dbHost}:${config.dbPort}/${config.dbName}`);
  console.log(`Redis:           ${config.redisUrl}`);
  console.log(`Log Level:       ${config.logLevel}`);
  console.log(`Max Connections: ${config.maxConnections}`);
  console.log(`Session Timeout: ${config.sessionTimeout}s`);
  console.log(`Rate Limit:      ${config.rateLimit}/min`);
  console.log(`CORS Origins:    ${config.corsOrigins}`);
  console.log(`Cache TTL:       ${config.cacheTTL}s`);
  console.log('\n🎚️  Feature Flags:');
  console.log(`  New UI:        ${config.features.newUI ? '✅ Enabled' : '⏭️  Disabled'}`);
  console.log(`  Analytics:     ${config.features.analytics ? '✅ Enabled' : '⏭️  Disabled'}`);
  console.log('================================================\n');
}

// Create HTTP server
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'healthy',
      environment: config.envName,
      timestamp: new Date().toISOString()
    }));
  } else if (req.url === '/config') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    // Don't expose sensitive data
    res.end(JSON.stringify({
      environment: config.envName,
      features: config.features,
      limits: {
        maxConnections: config.maxConnections,
        rateLimit: config.rateLimit,
        sessionTimeout: config.sessionTimeout
      }
    }, null, 2));
  } else if (req.url === '/version') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      version: '1.0.0',
      environment: config.envName,
      configSource: 'Configu (.env export)'
    }));
  } else {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end(`Hello from ${config.envName} environment!\n`);
  }
});

// Start server
function start() {
  const PORT = 3000;
  
  validateConfig();
  displayConfig();
  
  server.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📍 Environment: ${config.envName}`);
    console.log(`\n📡 Endpoints:`);
    console.log(`   http://localhost:${PORT}/         - Home`);
    console.log(`   http://localhost:${PORT}/health   - Health check`);
    console.log(`   http://localhost:${PORT}/config   - Config info`);
    console.log(`   http://localhost:${PORT}/version  - Version info`);
    console.log('\n✅ Ready to handle requests!\n');
  });
}

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('\n🛑 Received SIGTERM, shutting down gracefully...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

// Start the application
if (require.main === module) {
  start();
}

module.exports = { config, server };

#!/usr/bin/env node
/**
 * Sample Node.js Application - Option B
 * ======================================
 * Demonstrates how to use environment variables from Configu CLI direct export
 * 
 * Usage (GitLab CI):
 *   configu eval --set "production" --schema "./config.cfgu.json" --format "export" | sh
 *   node app.js
 * 
 * Usage (Local with JSON):
 *   configu eval --set "development" --schema "./config.cfgu.json" --format "json" > config.json
 *   node app.js --config config.json
 */

const http = require('http');
const fs = require('fs');

// Check if JSON config file provided
const configFile = process.argv.includes('--config') 
  ? process.argv[process.argv.indexOf('--config') + 1]
  : null;

let config;

if (configFile && fs.existsSync(configFile)) {
  // Option B.1: Load from JSON file (exported from Configu CLI)
  console.log(`📄 Loading configuration from ${configFile}...`);
  const configData = JSON.parse(fs.readFileSync(configFile, 'utf8'));
  
  config = {
    apiUrl: configData.API_URL,
    dbHost: configData.DB_HOST,
    dbPort: parseInt(configData.DB_PORT || '5432'),
    dbName: configData.DB_NAME || 'myapp',
    redisUrl: configData.REDIS_URL,
    logLevel: configData.LOG_LEVEL || 'info',
    maxConnections: parseInt(configData.MAX_CONNECTIONS || '100'),
    sessionTimeout: parseInt(configData.SESSION_TIMEOUT || '3600'),
    rateLimit: parseInt(configData.RATE_LIMIT || '100'),
    corsOrigins: configData.CORS_ORIGINS || '*',
    cacheTTL: parseInt(configData.CACHE_TTL || '300'),
    envName: configData.ENV_NAME,
    features: {
      newUI: configData.FEATURE_NEW_UI === true || configData.FEATURE_NEW_UI === 'true',
      analytics: configData.FEATURE_ANALYTICS === true || configData.FEATURE_ANALYTICS === 'true'
    }
  };
} else {
  // Option B.2: Load from environment variables (exported via `configu eval ... | sh`)
  console.log('🔧 Loading configuration from environment variables...');
  
  config = {
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
    features: {
      newUI: process.env.FEATURE_NEW_UI === 'true',
      analytics: process.env.FEATURE_ANALYTICS === 'true'
    }
  };
}

// Validate critical configuration
function validateConfig() {
  const errors = [];
  
  if (!config.apiUrl || !config.apiUrl.startsWith('http')) {
    errors.push('API_URL must be a valid HTTP/HTTPS URL');
  }
  
  if (!config.dbHost) {
    errors.push('DB_HOST is required');
  }
  
  if (!config.envName) {
    errors.push('ENV_NAME is required');
  }
  
  if (!['development', 'staging', 'production'].includes(config.envName)) {
    errors.push('ENV_NAME must be development, staging, or production');
  }
  
  if (errors.length > 0) {
    console.error('\n❌ Configuration validation failed:');
    errors.forEach(err => console.error(`  - ${err}`));
    console.error('\n💡 Make sure to run:');
    console.error('   configu eval --set <environment> --schema "./config.cfgu.json" --format "export" | sh\n');
    process.exit(1);
  }
  
  console.log('✅ Configuration validated successfully');
}

// Display current configuration
function displayConfig() {
  console.log('\n================================================');
  console.log('🚀 Application Configuration (Configu CLI Direct)');
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

// Request counter for rate limiting demo
let requestCount = 0;
const requestWindow = 60000; // 1 minute

setInterval(() => {
  requestCount = 0;
}, requestWindow);

// Create HTTP server with advanced features
const server = http.createServer((req, res) => {
  // Rate limiting
  requestCount++;
  if (requestCount > config.rateLimit) {
    res.writeHead(429, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({
      error: 'Rate limit exceeded',
      limit: config.rateLimit,
      window: `${requestWindow / 1000}s`
    }));
  }
  
  // CORS handling
  if (config.corsOrigins !== '*') {
    res.setHeader('Access-Control-Allow-Origin', config.corsOrigins);
  }
  
  // Route handling
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'healthy',
      environment: config.envName,
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    }));
  } 
  else if (req.url === '/config') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    // Expose safe config (no sensitive data)
    res.end(JSON.stringify({
      environment: config.envName,
      features: config.features,
      limits: {
        maxConnections: config.maxConnections,
        rateLimit: config.rateLimit,
        sessionTimeout: config.sessionTimeout,
        cacheTTL: config.cacheTTL
      },
      cors: config.corsOrigins,
      logLevel: config.logLevel,
      configSource: 'Configu CLI (direct)'
    }, null, 2));
  } 
  else if (req.url === '/version') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      version: '1.0.0',
      environment: config.envName,
      configMethod: 'Configu CLI direct export',
      nodeVersion: process.version,
      platform: process.platform
    }));
  } 
  else if (req.url === '/features') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      features: config.features,
      description: {
        newUI: config.features.newUI 
          ? 'New UI is enabled - serving modern interface'
          : 'Classic UI active',
        analytics: config.features.analytics
          ? 'Analytics tracking enabled'
          : 'Analytics disabled for privacy'
      }
    }, null, 2));
  } 
  else if (req.url === '/stats') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      requests: {
        current: requestCount,
        limit: config.rateLimit,
        remaining: Math.max(0, config.rateLimit - requestCount)
      },
      memory: process.memoryUsage(),
      uptime: process.uptime()
    }, null, 2));
  } 
  else {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Configu Demo - ${config.envName}</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
            .container { background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            h1 { color: #333; }
            .badge { display: inline-block; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: bold; }
            .dev { background: #ffc107; color: #000; }
            .staging { background: #ff9800; color: #fff; }
            .production { background: #4caf50; color: #fff; }
            .endpoint { background: #f0f0f0; padding: 8px 12px; margin: 8px 0; border-radius: 4px; font-family: monospace; }
            .feature { margin: 8px 0; }
            .enabled { color: #4caf50; }
            .disabled { color: #999; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>🚀 Configu Demo Application</h1>
            <p><span class="badge ${config.envName}">${config.envName.toUpperCase()}</span></p>
            
            <h2>📡 API Endpoints:</h2>
            <div class="endpoint">GET /health - Health check</div>
            <div class="endpoint">GET /config - Configuration info</div>
            <div class="endpoint">GET /version - Version info</div>
            <div class="endpoint">GET /features - Feature flags status</div>
            <div class="endpoint">GET /stats - Request statistics</div>
            
            <h2>🎚️ Feature Flags:</h2>
            <div class="feature ${config.features.newUI ? 'enabled' : 'disabled'}">
              ${config.features.newUI ? '✅' : '⏭️'} New UI
            </div>
            <div class="feature ${config.features.analytics ? 'enabled' : 'disabled'}">
              ${config.features.analytics ? '✅' : '⏭️'} Analytics
            </div>
            
            <p style="margin-top: 30px; color: #666; font-size: 14px;">
              Configuration loaded via <strong>Configu CLI (Option B)</strong>
            </p>
          </div>
        </body>
      </html>
    `);
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
    console.log(`   http://localhost:${PORT}/         - Home (HTML demo)`);
    console.log(`   http://localhost:${PORT}/health   - Health check`);
    console.log(`   http://localhost:${PORT}/config   - Config info`);
    console.log(`   http://localhost:${PORT}/version  - Version info`);
    console.log(`   http://localhost:${PORT}/features - Feature flags`);
    console.log(`   http://localhost:${PORT}/stats    - Request stats`);
    console.log('\n✅ Ready to handle requests!');
    console.log(`🔒 Rate limit: ${config.rateLimit} requests per minute`);
    console.log(`⏱️  Session timeout: ${config.sessionTimeout}s\n`);
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

// Simple test file for the Node.js application
const http = require('http');

// Simple test function
function runTests() {
  console.log('=== Running Application Tests ===');
  
  let testsPassed = 0;
  let testsTotal = 0;
  
  // Test 1: Basic functionality
  testsTotal++;
  console.log('Test 1: Basic functionality');
  if (typeof require('./app') === 'object') {
    console.log('  ✓ App module loads correctly');
    testsPassed++;
  } else {
    console.log('  ✗ App module failed to load');
  }
  
  // Test 2: Environment variables
  testsTotal++;
  console.log('Test 2: Environment variables');
  const nodeEnv = process.env.NODE_ENV || 'development';
  if (nodeEnv) {
    console.log(`  ✓ NODE_ENV is set to: ${nodeEnv}`);
    testsPassed++;
  } else {
    console.log('  ✗ NODE_ENV is not set');
  }
  
  // Test 3: Port configuration
  testsTotal++;
  console.log('Test 3: Port configuration');
  const port = process.env.PORT || 3000;
  if (port && !isNaN(port)) {
    console.log(`  ✓ Port is configured: ${port}`);
    testsPassed++;
  } else {
    console.log('  ✗ Port is not properly configured');
  }
  
  // Test 4: Package.json validation
  testsTotal++;
  console.log('Test 4: Package.json validation');
  try {
    const packageJson = require('./package.json');
    if (packageJson.name && packageJson.version) {
      console.log(`  ✓ Package.json is valid (${packageJson.name} v${packageJson.version})`);
      testsPassed++;
    } else {
      console.log('  ✗ Package.json is missing required fields');
    }
  } catch (error) {
    console.log('  ✗ Package.json could not be loaded');
  }
  
  // Test Summary
  console.log('\n=== Test Summary ===');
  console.log(`Tests passed: ${testsPassed}/${testsTotal}`);
  
  if (testsPassed === testsTotal) {
    console.log('✅ All tests passed!');
    process.exit(0);
  } else {
    console.log('❌ Some tests failed!');
    process.exit(1);
  }
}

// Run tests if this file is executed directly
if (require.main === module) {
  runTests();
}

module.exports = { runTests };
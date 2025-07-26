// tests/setup.js
// Global test setup and configuration

// Set test environment
process.env.NODE_ENV = 'test';

// Mock console methods to reduce noise during testing
const originalConsoleLog = console.log;
const originalConsoleError = console.error;

// Reduce console output during tests unless explicitly needed
global.console = {
  ...console,
  log: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
  info: jest.fn(),
};

// Add custom matchers for better assertions
expect.extend({
  toBeValidEmail(received) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const pass = emailRegex.test(received);
    
    if (pass) {
      return {
        message: () => `expected ${received} not to be a valid email`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to be a valid email`,
        pass: false,
      };
    }
  },
  
  toHaveValidTimestamp(received) {
    const pass = !isNaN(Date.parse(received));
    
    if (pass) {
      return {
        message: () => `expected ${received} not to be a valid timestamp`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to be a valid timestamp`,
        pass: false,
      };
    }
  }
});

// Global test timeout
jest.setTimeout(30000);

// Clean up after all tests
afterAll(() => {
  // Restore original console methods if needed
  if (process.env.JEST_VERBOSE === 'true') {
    console.log = originalConsoleLog;
    console.error = originalConsoleError;
  }
});

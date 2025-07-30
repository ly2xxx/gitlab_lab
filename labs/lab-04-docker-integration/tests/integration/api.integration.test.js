// tests/integration/api.integration.test.js
const request = require('supertest');
const app = require('../../src/server');

describe('API Integration Tests', () => {
  beforeAll(async () => {
    // Setup test environment
    process.env.NODE_ENV = 'test';
  });

  afterAll(async () => {
    // Cleanup
  });

  describe('Health Check Flow', () => {
    it('should provide comprehensive health status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body).toMatchObject({
        status: 'healthy',
        timestamp: expect.any(String),
        version: expect.any(String),
        environment: expect.any(String),
        uptime: expect.any(Number),
        memory: expect.any(Object)
      });

      // Validate timestamp format
      expect(response.body.timestamp).toHaveValidTimestamp();
    });
  });

  describe('User Management Flow', () => {
    it('should handle complete user lifecycle', async () => {
      // Get initial users
      const initialUsers = await request(app)
        .get('/api/users')
        .expect(200);

      expect(initialUsers.body).toHaveLength(3);

      // Create new user
      const newUser = {
        name: 'Integration Test User',
        email: 'integration@test.com',
        role: 'user'
      };

      const createResponse = await request(app)
        .post('/api/users')
        .send(newUser)
        .expect(201);

      expect(createResponse.body.id).toBeDefined();
      expect(createResponse.body.email).toBeValidEmail();
      
      // Update user
      const updateResponse = await request(app)
        .put(`/api/users/${createResponse.body.id}`)
        .send({ name: 'Updated Integration User' })
        .expect(200);
        
      expect(updateResponse.body).toHaveProperty('updatedAt');
      
      // Delete user
      await request(app)
        .delete(`/api/users/${createResponse.body.id}`)
        .expect(204);
    });
  });

  describe('System Monitoring Integration', () => {
    it('should provide system metrics', async () => {
      const systemResponse = await request(app)
        .get('/api/system')
        .expect(200);
        
      expect(systemResponse.body).toHaveProperty('nodeVersion');
      expect(systemResponse.body).toHaveProperty('platform');
      expect(systemResponse.body).toHaveProperty('memory');
      
      const metricsResponse = await request(app)
        .get('/metrics')
        .expect(200);
        
      expect(metricsResponse.text).toContain('nodejs_memory_usage_bytes');
      expect(metricsResponse.text).toContain('nodejs_process_uptime_seconds');
    });
  });
});
// tests/unit/server.test.js
const request = require('supertest');
const app = require('../../src/server');

describe('Server Unit Tests', () => {
  describe('Health Check Endpoint', () => {
    it('should return health status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('environment');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('memory');
    });
  });

  describe('Users API', () => {
    describe('GET /api/users', () => {
      it('should return list of users', async () => {
        const response = await request(app)
          .get('/api/users')
          .expect(200);

        expect(Array.isArray(response.body)).toBe(true);
        expect(response.body).toHaveLength(3);
        expect(response.body[0]).toHaveProperty('id');
        expect(response.body[0]).toHaveProperty('name');
        expect(response.body[0]).toHaveProperty('email');
        expect(response.body[0]).toHaveProperty('role');
      });
    });

    describe('GET /api/users/:id', () => {
      it('should return specific user', async () => {
        const response = await request(app)
          .get('/api/users/1')
          .expect(200);

        expect(response.body).toHaveProperty('id', 1);
        expect(response.body).toHaveProperty('name', 'John Doe');
        expect(response.body).toHaveProperty('email', 'john@example.com');
      });

      it('should return 404 for non-existent user', async () => {
        const response = await request(app)
          .get('/api/users/999')
          .expect(404);

        expect(response.body).toHaveProperty('error', 'User not found');
      });
    });

    describe('POST /api/users', () => {
      it('should create user with valid data', async () => {
        const userData = {
          name: 'Test User',
          email: 'test@example.com',
          role: 'user'
        };

        const response = await request(app)
          .post('/api/users')
          .send(userData)
          .expect(201);

        expect(response.body).toHaveProperty('id');
        expect(response.body.name).toBe(userData.name);
        expect(response.body.email).toBe(userData.email);
        expect(response.body.role).toBe(userData.role);
        expect(response.body).toHaveProperty('createdAt');
      });

      it('should validate required fields', async () => {
        await request(app)
          .post('/api/users')
          .send({})
          .expect(400);

        await request(app)
          .post('/api/users')
          .send({ name: 'Test' })
          .expect(400);

        await request(app)
          .post('/api/users')
          .send({ email: 'test@example.com' })
          .expect(400);
      });

      it('should validate email format', async () => {
        const response = await request(app)
          .post('/api/users')
          .send({
            name: 'Test User',
            email: 'invalid-email'
          })
          .expect(400);

        expect(response.body).toHaveProperty('error', 'Invalid email format');
      });
    });

    describe('PUT /api/users/:id', () => {
      it('should update user', async () => {
        const updateData = {
          name: 'Updated Name',
          email: 'updated@example.com'
        };

        const response = await request(app)
          .put('/api/users/1')
          .send(updateData)
          .expect(200);

        expect(response.body).toHaveProperty('id', 1);
        expect(response.body).toHaveProperty('updatedAt');
      });

      it('should require at least one field', async () => {
        await request(app)
          .put('/api/users/1')
          .send({})
          .expect(400);
      });
    });

    describe('DELETE /api/users/:id', () => {
      it('should delete user', async () => {
        await request(app)
          .delete('/api/users/1')
          .expect(204);
      });
    });
  });

  describe('System Info Endpoint', () => {
    it('should return system information', async () => {
      const response = await request(app)
        .get('/api/system')
        .expect(200);

      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('nodeVersion');
      expect(response.body).toHaveProperty('platform');
      expect(response.body).toHaveProperty('architecture');
      expect(response.body).toHaveProperty('environment');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('memory');
      expect(response.body).toHaveProperty('cpuUsage');
    });
  });

  describe('Metrics Endpoint', () => {
    it('should return prometheus metrics', async () => {
      const response = await request(app)
        .get('/metrics')
        .expect(200);

      expect(response.headers['content-type']).toBe('text/plain; charset=utf-8');
      expect(response.text).toContain('nodejs_memory_usage_bytes');
      expect(response.text).toContain('nodejs_process_uptime_seconds');
      expect(response.text).toContain('nodejs_cpu_usage_microseconds');
    });
  });

  describe('Error Handling', () => {
    it('should handle 404 routes', async () => {
      const response = await request(app)
        .get('/non-existent-route')
        .expect(404);

      expect(response.body).toHaveProperty('error', 'Route not found');
      expect(response.body).toHaveProperty('path', '/non-existent-route');
      expect(response.body).toHaveProperty('method', 'GET');
      expect(response.body).toHaveProperty('timestamp');
    });
  });
});

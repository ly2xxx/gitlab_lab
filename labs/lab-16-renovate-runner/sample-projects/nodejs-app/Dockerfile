# Multi-stage Node.js Dockerfile for Renovate testing
# Demonstrates version management that Renovate can update

# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Production stage  
FROM node:18-alpine AS production

# Security: Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

WORKDIR /app

# Copy dependencies from builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nodeuser:nodejs package*.json ./

# Copy application code
COPY --chown=nodeuser:nodejs src/ ./src/

# Security: Switch to non-root user
USER nodeuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "const http = require('http'); http.get('http://localhost:3000/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))"

# Expose port
EXPOSE 3000

# Start application
CMD ["npm", "start"]

# Labels for metadata
LABEL maintainer="GitLab Lab Tutorial"
LABEL version="1.0.0"
LABEL description="Sample Node.js app for Renovate Runner testing"
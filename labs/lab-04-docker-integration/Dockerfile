# Multi-stage Dockerfile for Node.js application
# This demonstrates Docker best practices and optimization techniques

# Stage 1: Build stage
FROM node:18-alpine AS builder

# Add metadata
LABEL maintainer="GitLab Tutorial"
LABEL description="GitLab Docker Integration Lab - Build Stage"

# Set working directory
WORKDIR /app

# Copy package files first (for better caching)
COPY package*.json ./

# Install all dependencies (including dev dependencies for testing)
RUN npm ci --no-audit --no-fund

# Copy source code
COPY . .

# Run tests in build stage
RUN npm test

# Run linting (if available)
RUN npm run lint || echo "Linting not available"

# Stage 2: Production stage
FROM node:18-alpine AS production

# Add metadata
LABEL maintainer="GitLab Tutorial"
LABEL description="GitLab Docker Integration Lab - Production Stage"

# Build arguments
ARG NODE_ENV=production
ARG APP_VERSION=1.0.0
ARG BUILD_DATE
ARG VCS_REF

# Environment variables
ENV NODE_ENV=$NODE_ENV
ENV APP_VERSION=$APP_VERSION
ENV PORT=3000

# Add build information as labels
LABEL version="$APP_VERSION"
LABEL build-date="$BUILD_DATE"
LABEL vcs-ref="$VCS_REF"
LABEL org.opencontainers.image.title="GitLab Docker Demo"
LABEL org.opencontainers.image.description="Demo application for GitLab Docker integration"
LABEL org.opencontainers.image.version="$APP_VERSION"
LABEL org.opencontainers.image.created="$BUILD_DATE"
LABEL org.opencontainers.image.revision="$VCS_REF"
LABEL org.opencontainers.image.source="https://github.com/ly2xxx/gitlab_lab"

# Install security updates and required packages
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
        dumb-init \
        curl \
        wget && \
    rm -rf /var/cache/apk/*

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 -G nodejs

# Set working directory
WORKDIR /app

# Change ownership of the app directory
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Copy package files
COPY --chown=nodejs:nodejs package*.json ./

# Install only production dependencies
RUN npm ci --only=production --no-audit --no-fund && \
    npm cache clean --force

# Copy application code from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/app.js .
COPY --from=builder --chown=nodejs:nodejs /app/test.js .

# Create necessary directories
RUN mkdir -p logs tmp

# Expose port
EXPOSE $PORT

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:$PORT/health || exit 1

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Start the application
CMD ["node", "app.js"]

# Stage 3: Development stage (optional)
FROM node:18-alpine AS development

# Add metadata
LABEL maintainer="GitLab Tutorial"
LABEL description="GitLab Docker Integration Lab - Development Stage"

# Environment variables
ENV NODE_ENV=development
ENV PORT=3000

# Install additional development tools
RUN apk add --no-cache \
        git \
        curl \
        wget \
        vim \
        bash && \
    rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev dependencies)
RUN npm ci --no-audit --no-fund

# Copy source code
COPY . .

# Expose port
EXPOSE $PORT

# Use nodemon for development
CMD ["npm", "run", "dev"]
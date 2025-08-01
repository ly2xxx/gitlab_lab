# Sample Dockerfile for testing the evergreen scanner
# This file intentionally uses older versions to demonstrate updates

# Multi-stage build example
FROM node:16.20.0-alpine AS builder
WORKDIR /build
COPY package*.json ./
RUN npm ci --only=production

FROM python:3.9.16-slim AS app
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

FROM nginx:1.23.0 AS proxy
COPY --from=builder /build/dist /usr/share/nginx/html
COPY --from=app /app /var/www/app

# Additional base images for testing
FROM redis:7.0.10-alpine AS redis
FROM postgres:14.7-alpine AS database

# Expose ports
EXPOSE 80 443 5432 6379

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

# Default command
CMD ["nginx", "-g", "daemon off;"]

#!/bin/bash
# Enhanced script to create sample files for the GitLab component
# Now configurable via environment variables for component reusability

set -e

# Configuration variables with defaults
APP_DIR="${SAMPLE_APP_PATH:-sample-app}"
PYTHON_VERSION="${PYTHON_BASE_VERSION:-3.9-slim}"
FLASK_VERSION="${FLASK_VERSION:-2.3.3}"
WERKZEUG_VERSION="${WERKZEUG_VERSION:-2.3.7}"
APP_NAME="${APP_NAME:-GitLab CI/CD Lab 11}"
APP_PORT="${APP_PORT:-8000}"

echo "Creating sample application files in $APP_DIR..."

# Create sample-app directory
mkdir -p "$APP_DIR"

# Create Dockerfile with configurable base image
cat > "$APP_DIR/Dockerfile" << EOF
# Sample Dockerfile for testing base image updates
FROM python:${PYTHON_VERSION}

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    gcc \\
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Expose port
EXPOSE ${APP_PORT}

# Set default command
CMD ["python", "app.py"]
EOF

# Create Python application with configurable settings
cat > "$APP_DIR/app.py" << EOF
#!/usr/bin/env python3
"""
Sample Flask application for GitLab CI/CD component
Configurable via environment variables
"""

from flask import Flask, jsonify
import os
import sys

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        'message': 'Hello from ${APP_NAME}!',
        'python_version': sys.version,
        'environment': os.environ.get('ENVIRONMENT', 'development'),
        'component_version': os.environ.get('COMPONENT_VERSION', '1.0.0')
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

@app.route('/info')
def info():
    return jsonify({
        'app_name': '${APP_NAME}',
        'port': ${APP_PORT},
        'python_version': sys.version_info[:2]
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=${APP_PORT}, debug=True)
EOF

# Create requirements file with configurable versions
cat > "$APP_DIR/requirements.txt" << EOF
Flask==${FLASK_VERSION}
Werkzeug==${WERKZEUG_VERSION}
EOF

# Create optional docker-compose file for local development
if [ "${CREATE_DOCKER_COMPOSE:-false}" = "true" ]; then
cat > "$APP_DIR/docker-compose.yml" << EOF
version: '3.8'
services:
  app:
    build: .
    ports:
      - "${APP_PORT}:${APP_PORT}"
    environment:
      - ENVIRONMENT=development
      - COMPONENT_VERSION=\${COMPONENT_VERSION:-1.0.0}
    volumes:
      - .:/app
    command: python app.py
EOF
fi

# Create .dockerignore file
cat > "$APP_DIR/.dockerignore" << 'EOF'
__pycache__
*.pyc
*.pyo
*.pyd
.env
.git
.gitignore
README.md
.pytest_cache
.coverage
.nyc_output
Dockerfile*
docker-compose*
EOF

# Create optional test file
if [ "${CREATE_TESTS:-false}" = "true" ]; then
mkdir -p "$APP_DIR/tests"
cat > "$APP_DIR/tests/test_app.py" << EOF
#!/usr/bin/env python3
"""
Simple tests for the sample application
"""

import pytest
import sys
import os

# Add app directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_home_route(client):
    """Test the home route returns expected JSON"""
    response = client.get('/')
    assert response.status_code == 200
    data = response.get_json()
    assert 'message' in data
    assert 'python_version' in data

def test_health_route(client):
    """Test the health check route"""
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'healthy'

def test_info_route(client):
    """Test the info route"""
    response = client.get('/info')
    assert response.status_code == 200
    data = response.get_json()
    assert 'app_name' in data
    assert 'port' in data
EOF

# Add pytest to requirements if tests are created
cat >> "$APP_DIR/requirements.txt" << EOF
pytest==7.4.2
EOF
fi

echo "Sample files created successfully in $APP_DIR!"
echo "Configuration used:"
echo "  - App Directory: $APP_DIR"
echo "  - Python Version: $PYTHON_VERSION"
echo "  - Flask Version: $FLASK_VERSION"
echo "  - App Port: $APP_PORT"
echo "  - Docker Compose: ${CREATE_DOCKER_COMPOSE:-false}"
echo "  - Tests: ${CREATE_TESTS:-false}"

# Display created files
echo ""
echo "Created files:"
find "$APP_DIR" -type f | sort
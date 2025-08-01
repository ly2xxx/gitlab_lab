#!/bin/bash
# Script to create sample files for the lab

set -e

echo "Creating sample application files..."

# Create sample-app directory
mkdir -p sample-app

# Create Dockerfile
cat > sample-app/Dockerfile << 'EOF'
# Sample Dockerfile for testing base image updates
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Expose port
EXPOSE 8000

# Set default command
CMD ["python", "app.py"]
EOF

# Create Python application
cat > sample-app/app.py << 'EOF'
#!/usr/bin/env python3
"""
Sample Flask application for GitLab CI/CD lab
"""

from flask import Flask, jsonify
import os
import sys

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        'message': 'Hello from GitLab CI/CD Lab 11!',
        'python_version': sys.version,
        'environment': os.environ.get('ENVIRONMENT', 'development')
    })

@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
EOF

# Create requirements file
cat > sample-app/requirements.txt << 'EOF'
Flask==2.3.3
Werkzeug==2.3.7
EOF

echo "Sample files created successfully!"
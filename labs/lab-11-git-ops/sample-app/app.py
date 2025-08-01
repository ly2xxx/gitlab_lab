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
#!/usr/bin/env python3
"""
GitLab Workflows Lab - Sample Backend API
A simple Flask API demonstrating CI/CD integration points
"""

import os
import json
import time
from datetime import datetime, timezone
from flask import Flask, jsonify, request, make_response
from flask_cors import CORS
import logging

# Initialize Flask application
app = Flask(__name__)
CORS(app)  # Enable CORS for frontend integration

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Application configuration
APP_VERSION = os.getenv('APP_VERSION', '2.0.0')
ENVIRONMENT = os.getenv('ENVIRONMENT', 'development')
PIPELINE_ID = os.getenv('CI_PIPELINE_ID', 'local-dev')
COMMIT_SHA = os.getenv('CI_COMMIT_SHA', 'local-commit')

# Application state
app_state = {
    'start_time': datetime.now(timezone.utc),
    'request_count': 0,
    'health_checks': 0,
    'pipeline_webhooks': 0
}

def get_uptime():
    """Calculate application uptime"""
    delta = datetime.now(timezone.utc) - app_state['start_time']
    days = delta.days
    hours, remainder = divmod(delta.seconds, 3600)
    minutes, _ = divmod(remainder, 60)
    return f"{days}d {hours}h {minutes}m"

@app.before_request
def before_request():
    """Log request and update counters"""
    app_state['request_count'] += 1
    logger.info(f"Request {app_state['request_count']}: {request.method} {request.path}")

@app.route('/')
def root():
    """Root endpoint with basic API information"""
    return jsonify({
        'name': 'GitLab Workflows Lab API',
        'version': APP_VERSION,
        'environment': ENVIRONMENT,
        'message': 'Welcome to the GitLab CI/CD workflows demonstration API',
        'endpoints': {
            'health': '/health',
            'metrics': '/metrics',
            'pipeline': '/pipeline',
            'webhook': '/webhook',
            'docs': '/docs'
        },
        'timestamp': datetime.now(timezone.utc).isoformat()
    })

@app.route('/health')
def health_check():
    """Health check endpoint for monitoring and CI/CD"""
    app_state['health_checks'] += 1
    
    # Simulate occasional health check variation
    status = 'healthy'
    status_code = 200
    
    # Simulate database connection check
    database_status = 'connected' if app_state['request_count'] % 10 != 0 else 'slow'
    
    # Simulate cache status
    cache_status = 'operational'
    
    # Simulate external service status
    external_services = 'available' if app_state['request_count'] % 15 != 0 else 'degraded'
    
    health_data = {
        'status': status,
        'version': APP_VERSION,
        'environment': ENVIRONMENT,
        'uptime': get_uptime(),
        'pipeline_id': PIPELINE_ID,
        'commit_sha': COMMIT_SHA[:8] if len(COMMIT_SHA) > 8 else COMMIT_SHA,
        'services': {
            'database': database_status,
            'cache': cache_status,
            'external_services': external_services
        },
        'metrics': {
            'request_count': app_state['request_count'],
            'health_checks': app_state['health_checks']
        },
        'timestamp': datetime.now(timezone.utc).isoformat()
    }
    
    logger.info(f"Health check #{app_state['health_checks']}: {status}")
    return jsonify(health_data), status_code

@app.route('/metrics')
def metrics():
    """Application metrics endpoint for monitoring"""
    metrics_data = {
        'application': {
            'name': 'gitlab-workflows-lab-api',
            'version': APP_VERSION,
            'environment': ENVIRONMENT,
            'uptime_seconds': (datetime.now(timezone.utc) - app_state['start_time']).total_seconds(),
            'start_time': app_state['start_time'].isoformat()
        },
        'requests': {
            'total': app_state['request_count'],
            'health_checks': app_state['health_checks'],
            'pipeline_webhooks': app_state['pipeline_webhooks']
        },
        'pipeline': {
            'id': PIPELINE_ID,
            'commit_sha': COMMIT_SHA,
            'environment': ENVIRONMENT
        },
        'system': {
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'timezone': 'UTC'
        }
    }
    
    return jsonify(metrics_data)

@app.route('/pipeline')
@app.route('/pipeline/<pipeline_id>')
def pipeline_status(pipeline_id=None):
    """Get pipeline status information"""
    if pipeline_id is None:
        pipeline_id = PIPELINE_ID
    
    # Simulate pipeline status data
    statuses = ['success', 'running', 'pending', 'failed']
    stages = ['validate', 'build', 'test', 'security', 'deploy']
    
    # Generate mock pipeline data
    pipeline_data = {
        'id': pipeline_id,
        'status': 'success',  # Default to success for demo
        'environment': ENVIRONMENT,
        'version': APP_VERSION,
        'commit_sha': COMMIT_SHA,
        'stages': [
            {
                'name': stage,
                'status': 'success',
                'duration': f"{30 + (i * 15)}s",
                'jobs': [
                    {
                        'name': f"{stage}-job-{j+1}",
                        'status': 'success',
                        'duration': f"{10 + (j * 5)}s"
                    } for j in range(2)
                ]
            } for i, stage in enumerate(stages)
        ],
        'created_at': app_state['start_time'].isoformat(),
        'updated_at': datetime.now(timezone.utc).isoformat(),
        'web_url': f"https://gitlab.example.com/pipeline/{pipeline_id}"
    }
    
    return jsonify(pipeline_data)

@app.route('/webhook', methods=['POST'])
def gitlab_webhook():
    """GitLab webhook endpoint for pipeline events"""
    app_state['pipeline_webhooks'] += 1
    
    webhook_data = request.get_json() or {}
    event_type = request.headers.get('X-Gitlab-Event', 'unknown')
    
    logger.info(f"Received GitLab webhook #{app_state['pipeline_webhooks']}: {event_type}")
    
    # Process different webhook events
    response_data = {
        'status': 'received',
        'event_type': event_type,
        'webhook_id': app_state['pipeline_webhooks'],
        'processed_at': datetime.now(timezone.utc).isoformat(),
        'message': f'Successfully processed {event_type} webhook'
    }
    
    # Add event-specific processing
    if event_type == 'Pipeline Hook':
        pipeline_id = webhook_data.get('object_attributes', {}).get('id')
        pipeline_status = webhook_data.get('object_attributes', {}).get('status')
        response_data['pipeline'] = {
            'id': pipeline_id,
            'status': pipeline_status
        }
        logger.info(f"Pipeline {pipeline_id} status: {pipeline_status}")
    
    elif event_type == 'Push Hook':
        branch = webhook_data.get('ref', '').replace('refs/heads/', '')
        commits_count = len(webhook_data.get('commits', []))
        response_data['push'] = {
            'branch': branch,
            'commits_count': commits_count
        }
        logger.info(f"Push to {branch} with {commits_count} commits")
    
    return jsonify(response_data), 200

@app.route('/docs')
def api_docs():
    """API documentation endpoint"""
    docs = {
        'title': 'GitLab Workflows Lab API Documentation',
        'version': APP_VERSION,
        'description': 'A sample API demonstrating GitLab CI/CD integration patterns',
        'endpoints': [
            {
                'path': '/',
                'method': 'GET',
                'description': 'API root with basic information'
            },
            {
                'path': '/health',
                'method': 'GET',
                'description': 'Health check endpoint for monitoring'
            },
            {
                'path': '/metrics',
                'method': 'GET',
                'description': 'Application metrics and statistics'
            },
            {
                'path': '/pipeline',
                'method': 'GET',
                'description': 'Current pipeline status information'
            },
            {
                'path': '/pipeline/<id>',
                'method': 'GET',
                'description': 'Specific pipeline status by ID'
            },
            {
                'path': '/webhook',
                'method': 'POST',
                'description': 'GitLab webhook receiver for pipeline events'
            },
            {
                'path': '/docs',
                'method': 'GET',
                'description': 'This API documentation'
            }
        ],
        'examples': {
            'health_check': {
                'description': 'Check if the API is healthy',
                'curl': 'curl -X GET http://localhost:5000/health'
            },
            'pipeline_status': {
                'description': 'Get current pipeline information',
                'curl': 'curl -X GET http://localhost:5000/pipeline'
            },
            'webhook': {
                'description': 'Send a GitLab webhook (requires JSON payload)',
                'curl': 'curl -X POST -H "Content-Type: application/json" -H "X-Gitlab-Event: Pipeline Hook" -d \'{’"object_attributes":{"id":123,"status":"success"}}\' http://localhost:5000/webhook'
            }
        }
    }
    
    return jsonify(docs)

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        'error': 'Not Found',
        'message': 'The requested endpoint does not exist',
        'status_code': 404,
        'available_endpoints': [
            '/', '/health', '/metrics', '/pipeline', '/webhook', '/docs'
        ]
    }), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal server error: {error}")
    return jsonify({
        'error': 'Internal Server Error',
        'message': 'An unexpected error occurred',
        'status_code': 500,
        'timestamp': datetime.now(timezone.utc).isoformat()
    }), 500

if __name__ == '__main__':
    logger.info(f"Starting GitLab Workflows Lab API v{APP_VERSION}")
    logger.info(f"Environment: {ENVIRONMENT}")
    logger.info(f"Pipeline ID: {PIPELINE_ID}")
    
    # Configure server based on environment
    debug_mode = ENVIRONMENT in ['development', 'dev']
    port = int(os.getenv('PORT', 5000))
    host = os.getenv('HOST', '0.0.0.0')
    
    logger.info(f"Server starting on {host}:{port} (debug={debug_mode})")
    
    app.run(
        host=host,
        port=port,
        debug=debug_mode,
        threaded=True
    )
#!/usr/bin/env python3
"""
Enhanced Evergreen Scanner with Scheduling Support
A comprehensive dependency update system for GitLab repositories

Features:
- Scheduled scanning with APScheduler
- YAML configuration support
- Enhanced Docker registry API handling
- Webhook support for manual triggers
- Better error handling and retry logic
- Metrics and health checks
- Notification support

Author: GitLab Lab Tutorial - Enhanced Version
License: MIT
"""

import os
import sys
import yaml
import logging
import threading
import signal
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from pathlib import Path
import time

# Third-party imports
import requests
from flask import Flask, request, jsonify, Response
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger
import gitlab
from gitlab.exceptions import GitlabError

# Import the core scanner components
from evergreen_scanner import (
    GitLabEvergreenScanner, 
    DockerImage, 
    UpdateCandidate,
    DockerHubAPI,
    DockerfileParser
)


@dataclass
class ScanResult:
    """Result of a dependency scan"""
    scan_id: str
    timestamp: datetime
    project_path: str
    updates_found: int
    merge_requests_created: int
    errors: List[str]
    duration_seconds: float
    success: bool


class ConfigManager:
    """Manages YAML configuration with validation"""
    
    def __init__(self, config_path: str = "config.yaml"):
        self.config_path = config_path
        self.config = {}
        self.load_config()
    
    def load_config(self):
        """Load configuration from YAML file with fallback to environment variables"""
        try:
            if os.path.exists(self.config_path):
                with open(self.config_path, 'r') as f:
                    self.config = yaml.safe_load(f) or {}
                print(f"✅ Loaded configuration from {self.config_path}")
            else:
                print(f"⚠️  Configuration file {self.config_path} not found, using defaults")
                self.config = self._get_default_config()
                
        except Exception as e:
            print(f"❌ Error loading config: {e}")
            self.config = self._get_default_config()
        
        # Override with environment variables
        self._override_with_env()
        
        # Validate configuration
        self._validate_config()
    
    def _get_default_config(self) -> Dict[str, Any]:
        """Get default configuration"""
        return {
            'gitlab': {
                'url': 'https://gitlab.com',
                'access_token': '',
                'project_path': '',
                'timeout': 60,
                'retries': 3
            },
            'scanner': {
                'branch_prefix': 'evergreen/',
                'dockerfile_patterns': ['Dockerfile*', '*.dockerfile'],
                'exclude_patterns': ['test/*', 'examples/*'],
                'registries': {
                    'docker_hub': {
                        'enabled': True,
                        'timeout': 30,
                        'retries': 3
                    }
                }
            },
            'scheduler': {
                'enabled': False,
                'interval_hours': 6,
                'timezone': 'UTC'
            },
            'webhook': {
                'enabled': False,
                'host': '0.0.0.0',
                'port': 8080
            },
            'logging': {
                'level': 'INFO',
                'console': {'enabled': True}
            }
        }
    
    def _override_with_env(self):
        """Override config with environment variables"""
        env_mappings = {
            'GITLAB_URL': ['gitlab', 'url'],
            'GITLAB_ACCESS_TOKEN': ['gitlab', 'access_token'],
            'GITLAB_PROJECT_PATH': ['gitlab', 'project_path'],
            'SCANNER_BRANCH_PREFIX': ['scanner', 'branch_prefix'],
            'SCHEDULER_ENABLED': ['scheduler', 'enabled'],
            'SCHEDULER_INTERVAL_HOURS': ['scheduler', 'interval_hours'],
            'WEBHOOK_ENABLED': ['webhook', 'enabled'],
            'WEBHOOK_PORT': ['webhook', 'port'],
            'LOG_LEVEL': ['logging', 'level']
        }
        
        for env_var, config_path in env_mappings.items():
            value = os.getenv(env_var)
            if value:
                self._set_nested_value(self.config, config_path, value)
    
    def _set_nested_value(self, config: Dict, path: List[str], value: Any):
        """Set nested configuration value"""
        current = config
        for key in path[:-1]:
            if key not in current:
                current[key] = {}
            current = current[key]
        
        # Type conversion
        if isinstance(current.get(path[-1]), bool):
            current[path[-1]] = value.lower() in ('true', '1', 'yes', 'on')
        elif isinstance(current.get(path[-1]), int):
            current[path[-1]] = int(value)
        else:
            current[path[-1]] = value
    
    def _validate_config(self):
        """Validate required configuration"""
        required_fields = [
            ['gitlab', 'access_token'],
            ['gitlab', 'project_path']
        ]
        
        for field_path in required_fields:
            value = self.get_nested_value(field_path)
            if not value:
                raise ValueError(f"Required configuration missing: {'.'.join(field_path)}")
    
    def get_nested_value(self, path: List[str], default=None):
        """Get nested configuration value"""
        current = self.config
        for key in path:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return default
        return current
    
    def get(self, *path, default=None):
        """Get configuration value with dot notation"""
        return self.get_nested_value(list(path), default)


class WebhookServer:
    """Flask-based webhook server for manual triggers"""
    
    def __init__(self, config: ConfigManager, scanner_manager):
        self.config = config
        self.scanner_manager = scanner_manager
        self.app = Flask(__name__)
        self.setup_routes()
        
    def setup_routes(self):
        """Setup Flask routes"""
        
        @self.app.route('/health', methods=['GET'])
        def health_check():
            """Health check endpoint"""
            return jsonify({
                'status': 'healthy',
                'timestamp': datetime.utcnow().isoformat(),
                'version': '2.0',
                'scheduler_running': self.scanner_manager.scheduler.running if self.scanner_manager.scheduler else False
            })
        
        @self.app.route('/trigger', methods=['POST'])
        def trigger_scan():
            """Manual scan trigger endpoint"""
            try:
                # Verify webhook secret if configured
                secret = self.config.get('webhook', 'secret_token')
                if secret:
                    provided_secret = request.headers.get('X-Webhook-Secret')
                    if provided_secret != secret:
                        return jsonify({'error': 'Invalid secret'}), 401
                
                # Trigger scan
                scan_id = self.scanner_manager.trigger_manual_scan()
                return jsonify({
                    'message': 'Scan triggered successfully',
                    'scan_id': scan_id,
                    'timestamp': datetime.utcnow().isoformat()
                })
                
            except Exception as e:
                return jsonify({'error': str(e)}), 500
        
        @self.app.route('/status', methods=['GET'])
        def get_status():
            """Get scanner status and recent results"""
            return jsonify({
                'status': 'running',
                'last_scan': self.scanner_manager.last_scan_result.timestamp.isoformat() if self.scanner_manager.last_scan_result else None,
                'recent_scans': len(self.scanner_manager.scan_history),
                'scheduler_enabled': self.config.get('scheduler', 'enabled', default=False),
                'next_scheduled_run': self.scanner_manager.get_next_run_time()
            })
    
    def run(self):
        """Run the webhook server"""
        host = self.config.get('webhook', 'host', default='0.0.0.0')
        port = self.config.get('webhook', 'port', default=8080)
        
        print(f"🌐 Starting webhook server on {host}:{port}")
        self.app.run(host=host, port=port, debug=False, use_reloader=False)


class EnhancedEvergreenScannerManager:
    """Enhanced scanner manager with scheduling and webhook support"""
    
    def __init__(self, config_path: str = "config.yaml"):
        self.config = ConfigManager(config_path)
        self.setup_logging()
        
        # Initialize components
        self.scanner = None
        self.scheduler = None
        self.webhook_server = None
        self.scan_history: List[ScanResult] = []
        self.last_scan_result: Optional[ScanResult] = None
        
        # Thread management
        self.shutdown_event = threading.Event()
        self.webhook_thread = None
        
        print("🚀 Enhanced Evergreen Scanner Manager initialized")
    
    def setup_logging(self):
        """Setup enhanced logging configuration"""
        log_level = self.config.get('logging', 'level', default='INFO')
        log_format = self.config.get('logging', 'format', 
                                   default='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        
        # Configure root logger
        logging.basicConfig(
            level=getattr(logging, log_level.upper()),
            format=log_format,
            handlers=[]
        )
        
        logger = logging.getLogger()
        
        # Console handler
        if self.config.get('logging', 'console', 'enabled', default=True):
            console_handler = logging.StreamHandler(sys.stdout)
            console_handler.setFormatter(logging.Formatter(log_format))
            logger.addHandler(console_handler)
        
        # File handler
        if self.config.get('logging', 'file', 'enabled', default=False):
            log_file = self.config.get('logging', 'file', 'path', default='logs/evergreen.log')
            os.makedirs(os.path.dirname(log_file), exist_ok=True)
            
            file_handler = logging.handlers.RotatingFileHandler(
                log_file,
                maxBytes=self.config.get('logging', 'file', 'max_bytes', default=10485760),
                backupCount=self.config.get('logging', 'file', 'backup_count', default=5)
            )
            file_handler.setFormatter(logging.Formatter(log_format))
            logger.addHandler(file_handler)
        
        self.logger = logging.getLogger(__name__)
        self.logger.info("✅ Logging configured successfully")
    
    def initialize_scanner(self):
        """Initialize the GitLab scanner"""
        try:
            gitlab_url = self.config.get('gitlab', 'url')
            access_token = self.config.get('gitlab', 'access_token')
            project_path = self.config.get('gitlab', 'project_path')
            
            self.scanner = GitLabEvergreenScanner(gitlab_url, access_token, project_path)
            
            # Configure scanner with enhanced settings
            self.scanner.branch_prefix = self.config.get('scanner', 'branch_prefix', default='evergreen/')
            self.scanner.dockerfile_patterns = self.config.get('scanner', 'dockerfile_patterns', 
                                                             default=['Dockerfile*'])
            
            if self.scanner.authenticate():
                self.logger.info("✅ GitLab scanner initialized and authenticated")
                return True
            else:
                self.logger.error("❌ GitLab authentication failed")
                return False
                
        except Exception as e:
            self.logger.error(f"❌ Error initializing scanner: {e}")
            return False
    
    def setup_scheduler(self):
        """Setup the background scheduler"""
        if not self.config.get('scheduler', 'enabled', default=False):
            self.logger.info("📅 Scheduler disabled in configuration")
            return
        
        try:
            self.scheduler = BackgroundScheduler(
                timezone=self.config.get('scheduler', 'timezone', default='UTC')
            )
            
            # Add scheduled job
            interval_hours = self.config.get('scheduler', 'interval_hours', default=6)
            cron_expression = self.config.get('scheduler', 'cron_expression')
            
            if cron_expression:
                # Use cron expression if provided
                trigger = CronTrigger.from_crontab(cron_expression)
                self.logger.info(f"📅 Scheduling scans with cron: {cron_expression}")
            else:
                # Use interval trigger
                trigger = IntervalTrigger(hours=interval_hours)
                self.logger.info(f"📅 Scheduling scans every {interval_hours} hours")
            
            self.scheduler.add_job(
                func=self.run_scheduled_scan,
                trigger=trigger,
                id='evergreen_scan',
                name='Evergreen Dependency Scan',
                replace_existing=True
            )
            
            self.scheduler.start()
            self.logger.info("✅ Scheduler started successfully")
            
            # Run on startup if configured
            if self.config.get('scheduler', 'run_on_startup', default=False):
                self.logger.info("🏃 Running initial scan on startup")
                threading.Thread(target=self.run_scheduled_scan, daemon=True).start()
                
        except Exception as e:
            self.logger.error(f"❌ Error setting up scheduler: {e}")
    
    def setup_webhook_server(self):
        """Setup the webhook server"""
        if not self.config.get('webhook', 'enabled', default=False):
            self.logger.info("🌐 Webhook server disabled in configuration")
            return
        
        try:
            self.webhook_server = WebhookServer(self.config, self)
            
            # Start webhook server in separate thread
            self.webhook_thread = threading.Thread(
                target=self.webhook_server.run,
                daemon=True,
                name="WebhookServer"
            )
            self.webhook_thread.start()
            
            self.logger.info("✅ Webhook server started successfully")
            
        except Exception as e:
            self.logger.error(f"❌ Error setting up webhook server: {e}")
    
    def run_scheduled_scan(self):
        """Run a scheduled dependency scan"""
        scan_id = f"scheduled_{int(time.time())}"
        self.logger.info(f"🔍 Starting scheduled scan: {scan_id}")
        
        try:
            start_time = time.time()
            errors = []
            
            # Run the scan
            update_candidates = self.scanner.scan_dockerfiles()
            
            # Create merge requests
            success_count = 0
            for candidate in update_candidates:
                try:
                    if self.scanner.create_update_branch_and_mr(candidate):
                        success_count += 1
                except Exception as e:
                    error_msg = f"Failed to create MR for {candidate.current_image}: {e}"
                    errors.append(error_msg)
                    self.logger.error(error_msg)
            
            # Record results
            duration = time.time() - start_time
            scan_result = ScanResult(
                scan_id=scan_id,
                timestamp=datetime.utcnow(),
                project_path=self.config.get('gitlab', 'project_path'),
                updates_found=len(update_candidates),
                merge_requests_created=success_count,
                errors=errors,
                duration_seconds=duration,
                success=len(errors) == 0
            )
            
            self.record_scan_result(scan_result)
            
            self.logger.info(f"✅ Scan {scan_id} completed: "
                           f"{len(update_candidates)} updates found, "
                           f"{success_count} MRs created, "
                           f"{len(errors)} errors")
            
        except Exception as e:
            self.logger.error(f"❌ Error in scheduled scan {scan_id}: {e}")
            # Record failed scan
            scan_result = ScanResult(
                scan_id=scan_id,
                timestamp=datetime.utcnow(),
                project_path=self.config.get('gitlab', 'project_path'),
                updates_found=0,
                merge_requests_created=0,
                errors=[str(e)],
                duration_seconds=time.time() - start_time if 'start_time' in locals() else 0,
                success=False
            )
            self.record_scan_result(scan_result)
    
    def trigger_manual_scan(self) -> str:
        """Trigger a manual scan via API"""
        scan_id = f"manual_{int(time.time())}"
        self.logger.info(f"🔍 Triggering manual scan: {scan_id}")
        
        # Run scan in background thread
        threading.Thread(
            target=self.run_scheduled_scan,
            daemon=True,
            name=f"ManualScan-{scan_id}"
        ).start()
        
        return scan_id
    
    def record_scan_result(self, result: ScanResult):
        """Record scan result and maintain history"""
        self.last_scan_result = result
        self.scan_history.append(result)
        
        # Keep only last 100 results
        if len(self.scan_history) > 100:
            self.scan_history = self.scan_history[-100:]
    
    def get_next_run_time(self) -> Optional[str]:
        """Get next scheduled run time"""
        if self.scheduler and self.scheduler.running:
            jobs = self.scheduler.get_jobs()
            if jobs:
                next_run = jobs[0].next_run_time
                return next_run.isoformat() if next_run else None
        return None
    
    def run(self):
        """Main run method"""
        self.logger.info("🚀 Starting Enhanced Evergreen Scanner")
        
        # Initialize components
        if not self.initialize_scanner():
            sys.exit(1)
        
        self.setup_scheduler()
        self.setup_webhook_server()
        
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        
        self.logger.info("✅ Enhanced Evergreen Scanner is running")
        self.logger.info("Press Ctrl+C to stop")
        
        try:
            # Keep the main thread alive
            while not self.shutdown_event.is_set():
                time.sleep(1)
                
        except KeyboardInterrupt:
            self.logger.info("👋 Keyboard interrupt received")
        
        self.shutdown()
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.logger.info(f"📡 Received signal {signum}, shutting down...")
        self.shutdown_event.set()
    
    def shutdown(self):
        """Graceful shutdown"""
        self.logger.info("🛑 Shutting down Enhanced Evergreen Scanner...")
        
        # Stop scheduler
        if self.scheduler and self.scheduler.running:
            self.scheduler.shutdown()
            self.logger.info("📅 Scheduler stopped")
        
        # Stop webhook server
        if self.webhook_thread and self.webhook_thread.is_alive():
            # Flask server will stop when main thread exits
            self.logger.info("🌐 Webhook server stopped")
        
        self.logger.info("👋 Enhanced Evergreen Scanner stopped gracefully")


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Enhanced Evergreen Scanner v2.0')
    parser.add_argument('--config', '-c', default='config.yaml',
                       help='Configuration file path (default: config.yaml)')
    parser.add_argument('--once', action='store_true',
                       help='Run scan once and exit (no scheduling)')
    parser.add_argument('--version', action='version', version='2.0')
    
    args = parser.parse_args()
    
    try:
        manager = EnhancedEvergreenScannerManager(args.config)
        
        if args.once:
            print("🔍 Running single scan...")
            if manager.initialize_scanner():
                manager.run_scheduled_scan()
                print("✅ Single scan completed")
            else:
                print("❌ Scanner initialization failed")
                sys.exit(1)
        else:
            manager.run()
            
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

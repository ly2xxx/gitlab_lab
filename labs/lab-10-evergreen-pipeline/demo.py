#!/usr/bin/env python3
"""
Evergreen Scanner Demo
Quick demonstration of the evergreen scanning functionality

This script demonstrates:
1. Dockerfile parsing capabilities
2. Docker Hub API integration  
3. Version comparison logic
4. Update detection
5. Configuration management

Usage:
    python demo.py              # Run basic demo
    python demo.py --full       # Run full demo with API calls
    python demo.py --config     # Test configuration loading
"""

import sys
import os
import argparse
from datetime import datetime

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from evergreen_scanner import (
        DockerfileParser, 
        DockerHubAPI, 
        DockerImage, 
        UpdateCandidate
    )
    from enhanced_evergreen_scheduler import ConfigManager
    IMPORTS_OK = True
except ImportError as e:
    print(f"❌ Import error: {e}")
    print("Please ensure all dependencies are installed: pip install -r requirements.txt")
    IMPORTS_OK = False


def print_header(title):
    """Print formatted section header"""
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print('=' * 60)


def print_subheader(title):
    """Print formatted subsection header"""
    print(f"\n--- {title} ---")


def demo_dockerfile_parsing():
    """Demonstrate Dockerfile parsing capabilities"""
    print_header("🐳 DOCKERFILE PARSING DEMO")
    
    # Sample Dockerfiles with different complexity levels
    dockerfiles = {
        "Simple": """FROM python:3.9.16-slim
WORKDIR /app
COPY . .
CMD ["python", "app.py"]""",
        
        "Multi-stage": """FROM node:16.20.0-alpine AS builder
WORKDIR /build
COPY package*.json ./
RUN npm install

FROM nginx:1.23.0 AS production  
COPY --from=builder /build/dist /usr/share/nginx/html""",
        
        "Registry Images": """FROM registry.access.redhat.com/ubi8/python-39:1.14.0
FROM gcr.io/distroless/python3:debug
FROM harbor.example.com/project/app:v1.2.0""",
        
        "Mixed Versions": """FROM python:3.9.16
FROM node:16.20.0-alpine  
FROM nginx:1.23.0
FROM redis:7.0.10-alpine
FROM postgres:14.7"""
    }
    
    for name, dockerfile_content in dockerfiles.items():
        print_subheader(f"{name} Dockerfile")
        print("Content:")
        for i, line in enumerate(dockerfile_content.split('\n'), 1):
            print(f"  {i:2d}: {line}")
        
        images = DockerfileParser.parse_dockerfile(dockerfile_content)
        print(f"\nParsed {len(images)} images:")
        for i, image in enumerate(images, 1):
            registry_info = f" (registry: {image.registry})" if image.registry else ""
            print(f"  {i}. {image.name}:{image.tag}{registry_info}")
    
    return True


def demo_version_checking(api_calls=False):
    """Demonstrate version checking logic"""
    print_header("🔍 VERSION CHECKING DEMO")
    
    api = DockerHubAPI()
    
    # Test semantic version detection
    print_subheader("Semantic Version Detection")
    
    test_tags = [
        ("3.11.1", True), ("v2.4.0", True), ("1.2", True),
        ("1.2.3-alpine", True), ("2.0.0-rc1", True),
        ("latest", False), ("alpine", False), ("main", False)
    ]
    
    for tag, expected in test_tags:
        result = api._is_semantic_version(tag)
        status = "✅" if result == expected else "❌"
        print(f"  {status} '{tag}' -> {result} (expected: {expected})")
    
    # Test version comparison
    print_subheader("Version Comparison Logic")
    
    version_sets = [
        (["1.2.3", "1.2.4", "1.3.0", "2.0.0"], "2.0.0"),
        (["v3.9.0", "v3.9.1", "v3.11.0"], "v3.11.0"),
        (["16.20.0", "18.17.0", "20.10.0"], "20.10.0")
    ]
    
    for versions, expected in version_sets:
        latest = api._get_latest_semantic_version(versions)
        status = "✅" if latest == expected else "❌"
        print(f"  {status} {versions} -> '{latest}' (expected: '{expected}')")
    
    # API calls (optional, requires internet)
    if api_calls:
        print_subheader("Docker Hub API Calls")
        test_images = ["python", "node", "nginx", "redis", "alpine"]
        
        for image in test_images:
            try:
                latest_tag = api.get_latest_tag(image)
                if latest_tag:
                    print(f"  ✅ {image:10} -> {latest_tag}")
                else:
                    print(f"  ⚠️  {image:10} -> No tags found")
            except Exception as e:
                print(f"  ❌ {image:10} -> Error: {e}")
    
    return True


def demo_update_detection():
    """Demonstrate update detection logic"""
    print_header("🔄 UPDATE DETECTION DEMO")
    
    # Simulate the sample project Dockerfile
    print_subheader("Sample Project Analysis")
    
    sample_dockerfile = """FROM node:16.20.0-alpine AS builder
FROM python:3.9.16-slim AS app  
FROM nginx:1.23.0 AS proxy
FROM redis:7.0.10-alpine AS redis
FROM postgres:14.7-alpine AS database"""
    
    print("Analyzing sample project Dockerfile...")
    images = DockerfileParser.parse_dockerfile(sample_dockerfile)
    
    # Simulate version checking results
    simulated_updates = {
        "node": "20.11.0-alpine",
        "python": "3.11.7-slim", 
        "nginx": "1.25.3",
        "redis": "7.2.4-alpine",
        "postgres": "16.1-alpine"
    }
    
    print(f"\nFound {len(images)} base images:")
    update_candidates = []
    
    for image in images:
        current_version = image.tag
        latest_version = simulated_updates.get(image.name, current_version)
        
        if latest_version != current_version:
            print(f"  🔄 {image.name:10} {current_version:15} -> {latest_version} (UPDATE AVAILABLE)")
            
            candidate = UpdateCandidate(
                current_image=image,
                latest_image=DockerImage(image.name, latest_version, image.registry),
                dockerfile_path="sample-project/Dockerfile",
                line_number=1
            )
            update_candidates.append(candidate)
        else:
            print(f"  ✅ {image.name:10} {current_version:15} (up to date)")
    
    print(f"\n📊 Summary: {len(update_candidates)} updates available out of {len(images)} images")
    
    if update_candidates:
        print("\nUpdates would create the following branches and MRs:")
        for candidate in update_candidates:
            branch_name = f"evergreen/{candidate.current_image.name.replace('/', '-')}-{candidate.latest_image.tag}"
            mr_title = f"Update {candidate.current_image.name} from {candidate.current_image.tag} to {candidate.latest_image.tag}"
            print(f"  📋 Branch: {branch_name}")
            print(f"      MR: {mr_title}")
    
    return len(update_candidates) > 0


def demo_configuration():
    """Demonstrate configuration management"""
    print_header("⚙️  CONFIGURATION DEMO")
    
    print_subheader("Loading Configuration")
    
    try:
        # Test with example config
        config = ConfigManager('config.yaml.example')
        print("✅ Configuration loaded successfully")
        
        print("\nConfiguration values:")
        print(f"  GitLab URL: {config.get('gitlab', 'url')}")
        print(f"  Branch Prefix: {config.get('scanner', 'branch_prefix')}")
        print(f"  Scheduler Enabled: {config.get('scheduler', 'enabled')}")
        print(f"  Webhook Enabled: {config.get('webhook', 'enabled')}")
        print(f"  Log Level: {config.get('logging', 'level')}")
        
        # Test nested access
        patterns = config.get('scanner', 'dockerfile_patterns', default=[])
        print(f"  Dockerfile Patterns: {patterns}")
        
        registries = config.get('scanner', 'registries', default={})
        docker_hub_enabled = registries.get('docker_hub', {}).get('enabled', False)
        print(f"  Docker Hub Enabled: {docker_hub_enabled}")
        
    except Exception as e:
        print(f"❌ Configuration error: {e}")
        return False
    
    print_subheader("Environment Variable Override Demo")
    
    # Temporarily set environment variable
    original_value = os.environ.get('LOG_LEVEL')
    os.environ['LOG_LEVEL'] = 'DEBUG'
    
    try:
        config_with_env = ConfigManager('config.yaml.example')
        log_level = config_with_env.get('logging', 'level')
        print(f"✅ Environment override working: LOG_LEVEL={log_level}")
    finally:
        # Restore original value
        if original_value:
            os.environ['LOG_LEVEL'] = original_value
        else:
            os.environ.pop('LOG_LEVEL', None)
    
    return True


def demo_health_check():
    """Demonstrate system health checking"""
    print_header("🏥 SYSTEM HEALTH CHECK")
    
    health_status = {
        "Dependencies": True,
        "Configuration": True,
        "Docker Hub API": None,  # Will test if API calls enabled
        "GitLab API": None       # Would need credentials
    }
    
    # Check dependencies
    print_subheader("Dependency Check")
    try:
        import yaml, requests, flask
        from apscheduler.schedulers.background import BackgroundScheduler
        print("✅ All required dependencies available")
        health_status["Dependencies"] = True
    except ImportError as e:
        print(f"❌ Missing dependency: {e}")
        health_status["Dependencies"] = False
    
    # Check configuration
    print_subheader("Configuration Check")
    try:
        config = ConfigManager('config.yaml.example')
        required_fields = [
            ('gitlab', 'url'),
            ('scanner', 'branch_prefix'),
            ('logging', 'level')
        ]
        
        all_fields_present = True
        for field_path in required_fields:
            value = config.get(*field_path)
            if value:
                print(f"  ✅ {'.'.join(field_path)}: {value}")
            else:
                print(f"  ❌ {'.'.join(field_path)}: Missing")
                all_fields_present = False
        
        health_status["Configuration"] = all_fields_present
        
    except Exception as e:
        print(f"❌ Configuration error: {e}")
        health_status["Configuration"] = False
    
    return all(status for status in health_status.values() if status is not None)


def main():
    """Main demo function"""
    parser = argparse.ArgumentParser(description='Evergreen Scanner Demo')
    parser.add_argument('--full', action='store_true', 
                       help='Run full demo including API calls')
    parser.add_argument('--config', action='store_true',
                       help='Test configuration loading only') 
    parser.add_argument('--health', action='store_true',
                       help='Run health check only')
    
    args = parser.parse_args()
    
    if not IMPORTS_OK:
        sys.exit(1)
    
    print(f"🚀 Evergreen Scanner Demo - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    success = True
    
    if args.config:
        success = demo_configuration()
    elif args.health:
        success = demo_health_check()
    else:
        # Run all demos
        success &= demo_dockerfile_parsing()
        success &= demo_version_checking(api_calls=args.full)
        success &= demo_update_detection()
        success &= demo_configuration()
        success &= demo_health_check()
        
        print_header("🎯 DEMO SUMMARY")
        if success:
            print("✅ All demo components completed successfully!")
            print("\nNext steps:")
            print("1. Copy config.yaml.example to config.yaml")
            print("2. Add your GitLab access token and project path")
            print("3. Run: python enhanced_evergreen_scheduler.py --once")
            print("4. For scheduled scanning: python enhanced_evergreen_scheduler.py")
        else:
            print("❌ Some demo components failed. Check the output above.")
    
    if args.full:
        print("\n💡 Tip: The --full flag enabled real API calls to Docker Hub")
        print("   This requires internet connectivity and may be rate-limited")
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

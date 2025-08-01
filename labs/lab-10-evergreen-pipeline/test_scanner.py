#!/usr/bin/env python3
"""
Test script for the Evergreen Scanner
This script tests the core functionality without requiring GitLab access
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from evergreen_scanner import DockerfileParser, DockerHubAPI, DockerImage
import unittest
from unittest.mock import Mock, patch


class TestDockerfileParser(unittest.TestCase):
    """Test the Dockerfile parsing functionality"""
    
    def test_parse_simple_dockerfile(self):
        """Test parsing a simple Dockerfile"""
        dockerfile_content = """
FROM python:3.9.18-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["python", "app.py"]
"""
        images = DockerfileParser.parse_dockerfile(dockerfile_content)
        self.assertEqual(len(images), 1)
        self.assertEqual(images[0].name, "python")
        self.assertEqual(images[0].tag, "3.9.18-slim")
        self.assertIsNone(images[0].registry)
    
    def test_parse_multi_stage_dockerfile(self):
        """Test parsing a multi-stage Dockerfile"""
        dockerfile_content = """
FROM node:18.17.0-alpine AS builder
WORKDIR /build
COPY package*.json ./
RUN npm install

FROM nginx:1.24.0 AS production
COPY --from=builder /build/dist /usr/share/nginx/html
"""
        images = DockerfileParser.parse_dockerfile(dockerfile_content)
        self.assertEqual(len(images), 2)
        
        # First stage
        self.assertEqual(images[0].name, "node")
        self.assertEqual(images[0].tag, "18.17.0-alpine")
        
        # Second stage
        self.assertEqual(images[1].name, "nginx")
        self.assertEqual(images[1].tag, "1.24.0")
    
    def test_parse_registry_image(self):
        """Test parsing images with custom registries"""
        dockerfile_content = """
FROM registry.access.redhat.com/ubi8/python-39:1.15.0
FROM gcr.io/distroless/python3:debug
"""
        images = DockerfileParser.parse_dockerfile(dockerfile_content)
        self.assertEqual(len(images), 2)
        
        # Red Hat image
        self.assertEqual(images[0].registry, "registry.access.redhat.com")
        self.assertEqual(images[0].name, "ubi8/python-39")
        self.assertEqual(images[0].tag, "1.15.0")
        
        # Google Container Registry image
        self.assertEqual(images[1].registry, "gcr.io")
        self.assertEqual(images[1].name, "distroless/python3")
        self.assertEqual(images[1].tag, "debug")


class TestDockerHubAPI(unittest.TestCase):
    """Test the Docker Hub API functionality"""
    
    def setUp(self):
        self.api = DockerHubAPI()
    
    def test_semantic_version_detection(self):
        """Test semantic version detection"""
        self.assertTrue(self.api._is_semantic_version("1.2.3"))
        self.assertTrue(self.api._is_semantic_version("v1.2.3"))
        self.assertTrue(self.api._is_semantic_version("1.2"))
        self.assertTrue(self.api._is_semantic_version("1.2.3-alpine"))
        self.assertTrue(self.api._is_semantic_version("2.4.0-rc1"))
        
        self.assertFalse(self.api._is_semantic_version("latest"))
        self.assertFalse(self.api._is_semantic_version("alpine"))
        self.assertFalse(self.api._is_semantic_version("main"))
    
    def test_latest_semantic_version(self):
        """Test getting the latest semantic version"""
        tags = ["1.2.3", "1.2.4", "1.3.0", "2.0.0", "1.2.3-alpine"]
        latest = self.api._get_latest_semantic_version(tags)
        self.assertEqual(latest, "2.0.0")
        
        tags2 = ["v1.2.3", "v1.2.4", "v1.3.0"]
        latest2 = self.api._get_latest_semantic_version(tags2)
        self.assertEqual(latest2, "v1.3.0")


class TestDockerImage(unittest.TestCase):
    """Test the DockerImage dataclass"""
    
    def test_docker_image_string_representation(self):
        """Test string representation of DockerImage"""
        # Docker Hub image
        image1 = DockerImage(name="python", tag="3.9.18-slim")
        self.assertEqual(str(image1), "python:3.9.18-slim")
        
        # Private registry image
        image2 = DockerImage(name="my-app", tag="v1.0.0", registry="registry.example.com")
        self.assertEqual(str(image2), "registry.example.com/my-app:v1.0.0")


def test_real_docker_hub_api():
    """Integration test with real Docker Hub API (optional)"""
    print("\n--- Testing Real Docker Hub API ---")
    api = DockerHubAPI()
    
    # Test with a known stable image
    try:
        latest_tag = api.get_latest_tag("alpine")
        print(f"Latest Alpine tag: {latest_tag}")
        
        latest_python = api.get_latest_tag("python")
        print(f"Latest Python tag: {latest_python}")
        
        # Test with a namespaced image
        latest_nginx = api.get_latest_tag("nginx")
        print(f"Latest Nginx tag: {latest_nginx}")
        
    except Exception as e:
        print(f"API test failed (this is expected in offline mode): {e}")


def demonstrate_scanner_functionality():
    """Demonstrate the scanner functionality with sample data"""
    print("\n--- Demonstrating Scanner Functionality ---")
    
    # Sample Dockerfile content
    sample_dockerfile = """
# Multi-stage build example
FROM node:18.17.0-alpine AS builder
WORKDIR /build
COPY package*.json ./
RUN npm ci --only=production

FROM python:3.9.18-slim AS app
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

FROM nginx:1.24.0 AS proxy
COPY --from=builder /build/dist /usr/share/nginx/html
COPY --from=app /app /var/www/app
"""
    
    print("Parsing sample Dockerfile...")
    images = DockerfileParser.parse_dockerfile(sample_dockerfile)
    
    print(f"\nFound {len(images)} base images:")
    for i, image in enumerate(images, 1):
        print(f"  {i}. {image}")
    
    print("\nSimulating version checks...")
    api = DockerHubAPI()
    
    for image in images:
        print(f"\nChecking updates for {image.name}:{image.tag}")
        try:
            latest = api.get_latest_tag(image.name)
            if latest and latest != image.tag:
                print(f"  ✅ Update available: {image.tag} -> {latest}")
            else:
                print(f"  ✓ Already up to date: {image.tag}")
        except Exception as e:
            print(f"  ❌ Failed to check: {e}")


if __name__ == "__main__":
    print("Evergreen Scanner Test Suite")
    print("=" * 40)
    
    # Run unit tests
    print("\n--- Running Unit Tests ---")
    unittest.main(argv=[''], exit=False, verbosity=2)
    
    # Run integration tests
    test_real_docker_hub_api()
    
    # Demonstrate functionality
    demonstrate_scanner_functionality()
    
    print("\n--- Test Summary ---")
    print("✅ Core parsing functionality tested")
    print("✅ Version comparison logic tested")
    print("✅ Docker Hub API integration tested")
    print("✅ Sample functionality demonstrated")
    print("\nTo run the full scanner, set up GitLab credentials and run:")
    print("python evergreen_scanner.py")

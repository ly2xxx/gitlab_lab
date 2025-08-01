#!/usr/bin/env python3
"""
Enhanced Test Suite for Evergreen Scanner
Comprehensive testing including unit, integration, and system tests

Author: GitLab Lab Tutorial - Enhanced Tests
License: MIT
"""

import sys
import os
import unittest
import tempfile
import yaml
import json
import time
from unittest.mock import Mock, patch, MagicMock
from datetime import datetime, timedelta
import threading
import requests

# Add the lab directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from evergreen_scanner import (
    DockerfileParser, 
    DockerHubAPI, 
    DockerImage, 
    UpdateCandidate,
    GitLabEvergreenScanner
)

# Test the enhanced scheduler if available
try:
    from enhanced_evergreen_scheduler import (
        ConfigManager,
        EnhancedEvergreenScannerManager,
        ScanResult,
        WebhookServer
    )
    ENHANCED_AVAILABLE = True
except ImportError:
    ENHANCED_AVAILABLE = False
    print("⚠️  Enhanced scheduler not available for testing")


class TestDockerfileParser(unittest.TestCase):
    """Enhanced tests for Dockerfile parsing"""
    
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
FROM harbor.example.com/project/app:v1.0.0
"""
        images = DockerfileParser.parse_dockerfile(dockerfile_content)
        self.assertEqual(len(images), 3)
        
        # Red Hat image
        self.assertEqual(images[0].registry, "registry.access.redhat.com")
        self.assertEqual(images[0].name, "ubi8/python-39")
        self.assertEqual(images[0].tag, "1.15.0")
        
        # Google Container Registry image
        self.assertEqual(images[1].registry, "gcr.io")
        self.assertEqual(images[1].name, "distroless/python3")
        self.assertEqual(images[1].tag, "debug")
        
        # Harbor registry
        self.assertEqual(images[2].registry, "harbor.example.com")
        self.assertEqual(images[2].name, "project/app")
        self.assertEqual(images[2].tag, "v1.0.0")
    
    def test_parse_scratch_and_build_args(self):
        """Test parsing with scratch images and build args"""
        dockerfile_content = """
ARG BASE_IMAGE=python:3.9
FROM scratch
FROM $BASE_IMAGE
FROM ${BASE_IMAGE:-python:3.9}
"""
        images = DockerfileParser.parse_dockerfile(dockerfile_content)
        # Should skip scratch and build arg references
        self.assertEqual(len(images), 0)
    
    def test_parse_comments_and_empty_lines(self):
        """Test parsing with comments and empty lines"""
        dockerfile_content = """
# This is a comment
FROM python:3.9

# Another comment
FROM nginx:1.20
# FROM commented_image:latest
"""
        images = DockerfileParser.parse_dockerfile(dockerfile_content)
        self.assertEqual(len(images), 2)
        self.assertEqual(images[0].name, "python")
        self.assertEqual(images[1].name, "nginx")


class TestDockerHubAPI(unittest.TestCase):
    """Enhanced tests for Docker Hub API"""
    
    def setUp(self):
        self.api = DockerHubAPI()
    
    def test_semantic_version_detection(self):
        """Test semantic version detection patterns"""
        test_cases = [
            ("1.2.3", True),
            ("v1.2.3", True),
            ("1.2", True),
            ("1.2.3-alpine", True),
            ("2.4.0-rc1", True),
            ("1.2.3-slim-bullseye", True),
            ("latest", False),
            ("alpine", False),
            ("main", False),
            ("master", False),
            ("stable", False),
            ("edge", False)
        ]
        
        for tag, expected in test_cases:
            with self.subTest(tag=tag):
                result = self.api._is_semantic_version(tag)
                self.assertEqual(result, expected, f"Tag '{tag}' should be {expected}")
    
    def test_latest_semantic_version_comparison(self):
        """Test semantic version comparison logic"""
        test_cases = [
            (["1.2.3", "1.2.4", "1.3.0", "2.0.0"], "2.0.0"),
            (["v1.2.3", "v1.2.4", "v1.3.0"], "v1.3.0"),
            (["3.9.0", "3.9.1", "3.10.0", "3.11.0"], "3.11.0"),
            (["1.0.0-alpha", "1.0.0-beta", "1.0.0"], "1.0.0"),
            (["2.1", "2.2.1", "2.3.0"], "2.3.0")
        ]
        
        for tags, expected in test_cases:
            with self.subTest(tags=tags):
                result = self.api._get_latest_semantic_version(tags)
                self.assertEqual(result, expected)
    
    @patch('requests.Session.get')
    def test_get_latest_tag_success(self, mock_get):
        """Test successful API response"""
        mock_response = Mock()
        mock_response.raise_for_status.return_value = None
        mock_response.json.return_value = {
            'results': [
                {'name': '3.11.1', 'last_updated': '2023-01-01T00:00:00Z'},
                {'name': '3.11.0', 'last_updated': '2022-12-01T00:00:00Z'},
                {'name': 'latest', 'last_updated': '2023-01-02T00:00:00Z'}
            ]
        }
        mock_get.return_value = mock_response
        
        result = self.api.get_latest_tag('python')
        self.assertEqual(result, '3.11.1')
    
    @patch('requests.Session.get')
    def test_get_latest_tag_api_error(self, mock_get):
        """Test API error handling"""
        mock_get.side_effect = requests.RequestException("API Error")
        
        result = self.api.get_latest_tag('python')
        self.assertIsNone(result)
    
    @patch('requests.Session.get')
    def test_get_latest_tag_no_semantic_versions(self, mock_get):
        """Test fallback to 'latest' when no semantic versions found"""
        mock_response = Mock()
        mock_response.raise_for_status.return_value = None
        mock_response.json.return_value = {
            'results': [
                {'name': 'alpine', 'last_updated': '2023-01-01T00:00:00Z'},
                {'name': 'latest', 'last_updated': '2023-01-02T00:00:00Z'}
            ]
        }
        mock_get.return_value = mock_response
        
        result = self.api.get_latest_tag('alpine')
        self.assertEqual(result, 'latest')


class TestDockerImage(unittest.TestCase):
    """Test DockerImage dataclass functionality"""
    
    def test_docker_image_string_representation(self):
        """Test string representation of DockerImage"""
        # Docker Hub image
        image1 = DockerImage(name="python", tag="3.9.18-slim")
        self.assertEqual(str(image1), "python:3.9.18-slim")
        
        # Private registry image
        image2 = DockerImage(name="my-app/backend", tag="v1.0.0", registry="registry.example.com")
        self.assertEqual(str(image2), "registry.example.com/my-app/backend:v1.0.0")
        
        # Official library image
        image3 = DockerImage(name="nginx", tag="latest")
        self.assertEqual(str(image3), "nginx:latest")


class TestUpdateCandidate(unittest.TestCase):
    """Test UpdateCandidate functionality"""
    
    def test_update_candidate_creation(self):
        """Test UpdateCandidate data structure"""
        current = DockerImage(name="python", tag="3.9.0")
        latest = DockerImage(name="python", tag="3.11.0")
        
        candidate = UpdateCandidate(
            current_image=current,
            latest_image=latest,
            dockerfile_path="Dockerfile",
            line_number=1
        )
        
        self.assertEqual(candidate.current_image.tag, "3.9.0")
        self.assertEqual(candidate.latest_image.tag, "3.11.0")
        self.assertEqual(candidate.dockerfile_path, "Dockerfile")


@unittest.skipUnless(ENHANCED_AVAILABLE, "Enhanced scheduler not available")
class TestConfigManager(unittest.TestCase):
    """Test enhanced configuration management"""
    
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.config_file = os.path.join(self.temp_dir, 'test_config.yaml')
    
    def tearDown(self):
        import shutil
        shutil.rmtree(self.temp_dir)
    
    def test_load_yaml_config(self):
        """Test loading YAML configuration"""
        config_data = {
            'gitlab': {
                'url': 'https://test.gitlab.com',
                'access_token': 'test_token',
                'project_path': 'test/project'
            },
            'scheduler': {
                'enabled': True,
                'interval_hours': 12
            }
        }
        
        with open(self.config_file, 'w') as f:
            yaml.dump(config_data, f)
        
        config_manager = ConfigManager(self.config_file)
        
        self.assertEqual(config_manager.get('gitlab', 'url'), 'https://test.gitlab.com')
        self.assertEqual(config_manager.get('scheduler', 'interval_hours'), 12)
        self.assertTrue(config_manager.get('scheduler', 'enabled'))
    
    def test_environment_variable_override(self):
        """Test environment variable overrides"""
        config_data = {
            'gitlab': {
                'url': 'https://default.gitlab.com',
                'access_token': 'default_token'
            }
        }
        
        with open(self.config_file, 'w') as f:
            yaml.dump(config_data, f)
        
        # Set environment variable
        os.environ['GITLAB_URL'] = 'https://override.gitlab.com'
        
        try:
            config_manager = ConfigManager(self.config_file)
            self.assertEqual(config_manager.get('gitlab', 'url'), 'https://override.gitlab.com')
        finally:
            del os.environ['GITLAB_URL']
    
    def test_missing_config_file(self):
        """Test behavior with missing config file"""
        config_manager = ConfigManager('/nonexistent/config.yaml')
        
        # Should use defaults
        self.assertEqual(config_manager.get('gitlab', 'url'), 'https://gitlab.com')
        self.assertEqual(config_manager.get('scanner', 'branch_prefix'), 'evergreen/')


@unittest.skipUnless(ENHANCED_AVAILABLE, "Enhanced scheduler not available")
class TestScanResult(unittest.TestCase):
    """Test ScanResult data structure"""
    
    def test_scan_result_creation(self):
        """Test ScanResult data structure"""
        result = ScanResult(
            scan_id="test_scan_001",
            timestamp=datetime.utcnow(),
            project_path="test/project",
            updates_found=3,
            merge_requests_created=2,
            errors=["API timeout"],
            duration_seconds=45.5,
            success=False
        )
        
        self.assertEqual(result.scan_id, "test_scan_001")
        self.assertEqual(result.updates_found, 3)
        self.assertEqual(result.merge_requests_created, 2)
        self.assertFalse(result.success)
        self.assertEqual(len(result.errors), 1)


class TestIntegration(unittest.TestCase):
    """Integration tests for the complete system"""
    
    @patch('gitlab.Gitlab')
    def test_gitlab_scanner_initialization(self, mock_gitlab):
        """Test GitLab scanner initialization"""
        mock_gl_instance = Mock()
        mock_project = Mock()
        mock_project.name = "test-project"
        mock_gl_instance.projects.get.return_value = mock_project
        mock_gitlab.return_value = mock_gl_instance
        
        scanner = GitLabEvergreenScanner(
            gitlab_url="https://gitlab.com",
            access_token="test_token",
            project_path="test/project"
        )
        
        self.assertTrue(scanner.authenticate())
        self.assertEqual(scanner.project.name, "test-project")
    
    @patch('requests.Session.get')
    def test_end_to_end_version_check(self, mock_get):
        """Test end-to-end version checking flow"""
        # Mock Docker Hub API response
        mock_response = Mock()
        mock_response.raise_for_status.return_value = None
        mock_response.json.return_value = {
            'results': [
                {'name': '3.11.1', 'last_updated': '2023-01-01T00:00:00Z'},
                {'name': '3.9.18', 'last_updated': '2022-12-01T00:00:00Z'}
            ]
        }
        mock_get.return_value = mock_response
        
        # Test the complete flow
        dockerfile_content = "FROM python:3.9.18-slim"
        images = DockerfileParser.parse_dockerfile(dockerfile_content)
        
        api = DockerHubAPI()
        latest_tag = api.get_latest_tag(images[0].name)
        
        self.assertEqual(latest_tag, '3.11.1')
        self.assertNotEqual(latest_tag, images[0].tag)


class TestPerformance(unittest.TestCase):
    """Performance tests for critical components"""
    
    def test_dockerfile_parsing_performance(self):
        """Test performance of Dockerfile parsing"""
        # Create a large Dockerfile with many FROM statements
        large_dockerfile = "\n".join([
            f"FROM python:{i}.0-slim AS stage{i}"
            for i in range(1, 101)
        ])
        
        start_time = time.time()
        images = DockerfileParser.parse_dockerfile(large_dockerfile)
        end_time = time.time()
        
        self.assertEqual(len(images), 100)
        self.assertLess(end_time - start_time, 1.0)  # Should complete in under 1 second
    
    def test_version_comparison_performance(self):
        """Test performance of version comparison"""
        api = DockerHubAPI()
        tags = [f"1.2.{i}" for i in range(1000)]
        
        start_time = time.time()
        latest = api._get_latest_semantic_version(tags)
        end_time = time.time()
        
        self.assertEqual(latest, "1.2.999")
        self.assertLess(end_time - start_time, 0.1)  # Should be very fast


def run_test_suite():
    """Run the complete test suite with detailed reporting"""
    print("🧪 Enhanced Evergreen Scanner Test Suite")
    print("=" * 50)
    
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test classes
    test_classes = [
        TestDockerfileParser,
        TestDockerHubAPI,
        TestDockerImage,
        TestUpdateCandidate,
        TestIntegration,
        TestPerformance
    ]
    
    if ENHANCED_AVAILABLE:
        test_classes.extend([
            TestConfigManager,
            TestScanResult
        ])
    
    for test_class in test_classes:
        tests = loader.loadTestsFromTestCase(test_class)
        suite.addTests(tests)
    
    # Run tests with detailed output
    runner = unittest.TextTestRunner(
        verbosity=2,
        stream=sys.stdout,
        buffer=True
    )
    
    result = runner.run(suite)
    
    # Print summary
    print("\n" + "=" * 50)
    print("📊 Test Summary")
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print(f"Skipped: {len(result.skipped)}")
    print(f"Success rate: {((result.testsRun - len(result.failures) - len(result.errors)) / result.testsRun * 100):.1f}%")
    
    if result.failures:
        print("\n❌ Failures:")
        for test, failure in result.failures:
            print(f"  - {test}: {failure.split('AssertionError:')[-1].strip()}")
    
    if result.errors:
        print("\n💥 Errors:")
        for test, error in result.errors:
            print(f"  - {test}: {error.split('Exception:')[-1].strip()}")
    
    # Return success status
    return len(result.failures) == 0 and len(result.errors) == 0


def run_integration_tests():
    """Run integration tests with real APIs (optional)"""
    print("\n🌐 Integration Tests (Real APIs)")
    print("-" * 30)
    
    try:
        print("Testing Docker Hub API connectivity...")
        api = DockerHubAPI()
        
        # Test with stable images
        test_images = ["alpine", "python", "nginx"]
        for image in test_images:
            try:
                latest_tag = api.get_latest_tag(image)
                if latest_tag:
                    print(f"✅ {image}: {latest_tag}")
                else:
                    print(f"⚠️  {image}: No tags found")
            except Exception as e:
                print(f"❌ {image}: {e}")
        
        print("✅ Integration tests completed")
        
    except Exception as e:
        print(f"❌ Integration test failed: {e}")


if __name__ == "__main__":
    # Run main test suite
    success = run_test_suite()
    
    # Run integration tests if requested
    if "--integration" in sys.argv:
        run_integration_tests()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

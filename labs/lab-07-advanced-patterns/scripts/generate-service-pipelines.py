#!/usr/bin/env python3
# scripts/generate-service-pipelines.py

import json
import os
from pathlib import Path
from jinja2 import Environment, FileSystemLoader

def load_services_matrix():
    """Load the services discovery matrix"""
    if not os.path.exists('services-matrix.json'):
        print("Services matrix not found. Using default configuration.")
        return {
            "changed_services": "frontend backend api-gateway user-service notification-service",
            "all_services": "frontend,backend,api-gateway,user-service,notification-service",
            "dependencies": {
                "frontend": ["api-gateway"],
                "backend": ["user-service", "notification-service"],
                "api-gateway": ["user-service"],
                "user-service": [],
                "notification-service": ["user-service"]
            },
            "build_order": ["user-service", "notification-service", "api-gateway", "backend", "frontend"]
        }
    
    with open('services-matrix.json', 'r') as f:
        return json.load(f)

def detect_service_type(service_path):
    """Detect the type of service based on files in the directory"""
    service_dir = Path(f"services/{service_path}")
    
    if not service_dir.exists():
        return "generic"
    
    # Check for different service types
    if (service_dir / "package.json").exists():
        return "nodejs"
    elif (service_dir / "pom.xml").exists():
        return "maven"
    elif (service_dir / "requirements.txt").exists():
        return "python"
    elif (service_dir / "go.mod").exists():
        return "golang"
    elif (service_dir / "Dockerfile").exists():
        return "docker"
    else:
        return "generic"

def generate_service_pipeline(service_name, service_config, services_matrix):
    """Generate pipeline configuration for a specific service"""
    service_type = detect_service_type(service_name)
    dependencies = services_matrix["dependencies"].get(service_name, [])
    
    pipeline_config = {
        "stages": ["build", "test", "package"],
        "variables": {
            "SERVICE_NAME": service_name,
            "SERVICE_PATH": f"services/{service_name}",
            "SERVICE_TYPE": service_type
        },
        "jobs": {}
    }
    
    # Build job
    pipeline_config["jobs"][f"build-{service_name}"] = {
        "stage": "build",
        "image": get_build_image(service_type),
        "script": generate_build_script(service_type, service_name),
        "artifacts": {
            "paths": [f"services/{service_name}/dist/", f"services/{service_name}/target/"],
            "expire_in": "1 hour"
        }
    }
    
    # Test job
    pipeline_config["jobs"][f"test-{service_name}"] = {
        "stage": "test",
        "image": get_build_image(service_type),
        "script": generate_test_script(service_type, service_name),
        "dependencies": [f"build-{service_name}"],
        "artifacts": {
            "reports": {
                "junit": f"services/{service_name}/test-results.xml",
                "coverage_report": {
                    "coverage_format": "cobertura",
                    "path": f"services/{service_name}/coverage.xml"
                }
            }
        }
    }
    
    # Package job (Docker image)
    pipeline_config["jobs"][f"package-{service_name}"] = {
        "stage": "package",
        "image": "docker:24",
        "services": ["docker:24-dind"],
        "script": [
            "docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY",
            f"cd services/{service_name}",
            f"docker build -t $CI_REGISTRY_IMAGE/{service_name}:$CI_COMMIT_SHA .",
            f"docker push $CI_REGISTRY_IMAGE/{service_name}:$CI_COMMIT_SHA"
        ],
        "dependencies": [f"test-{service_name}"]
    }
    
    # Add dependency jobs if needed
    if dependencies:
        for dep in dependencies:
            pipeline_config["jobs"][f"test-{service_name}"]["needs"] = pipeline_config["jobs"][f"test-{service_name}"].get("needs", [])
            pipeline_config["jobs"][f"test-{service_name}"]["needs"].append(f"package-{dep}")
    
    return pipeline_config

def get_build_image(service_type):
    """Get the appropriate build image for the service type"""
    images = {
        "nodejs": "node:18",
        "maven": "maven:3.8-openjdk-17",
        "python": "python:3.9",
        "golang": "golang:1.19",
        "docker": "alpine:latest",
        "generic": "alpine:latest"
    }
    return images.get(service_type, "alpine:latest")

def generate_build_script(service_type, service_name):
    """Generate build script based on service type"""
    scripts = {
        "nodejs": [
            f"cd services/{service_name}",
            "npm ci",
            "npm run build"
        ],
        "maven": [
            f"cd services/{service_name}",
            "mvn clean compile"
        ],
        "python": [
            f"cd services/{service_name}",
            "pip install -r requirements.txt",
            "python setup.py build"
        ],
        "golang": [
            f"cd services/{service_name}",
            "go mod download",
            "go build -o bin/app ."
        ],
        "generic": [
            f"echo 'Building {service_name}'",
            f"cd services/{service_name}",
            "ls -la"
        ]
    }
    return scripts.get(service_type, scripts["generic"])

def generate_test_script(service_type, service_name):
    """Generate test script based on service type"""
    scripts = {
        "nodejs": [
            f"cd services/{service_name}",
            "npm test -- --coverage --reporters=junit"
        ],
        "maven": [
            f"cd services/{service_name}",
            "mvn test"
        ],
        "python": [
            f"cd services/{service_name}",
            "python -m pytest --junit-xml=test-results.xml --cov=. --cov-report=xml"
        ],
        "golang": [
            f"cd services/{service_name}",
            "go test -v ./... -coverprofile=coverage.out",
            "go tool cover -html=coverage.out -o coverage.html"
        ],
        "generic": [
            f"echo 'Testing {service_name}'",
            f"cd services/{service_name}",
            "echo 'Tests completed'"
        ]
    }
    return scripts.get(service_type, scripts["generic"])

def generate_matrix_pipeline(services_matrix):
    """Generate a matrix-based pipeline for all services"""
    changed_services = services_matrix["changed_services"].split()
    all_services = services_matrix["all_services"].split(",")
    
    # Only build changed services in feature branches, all services in main
    services_to_build = changed_services if changed_services else all_services
    
    matrix_pipeline = {
        "stages": ["build", "test", "package"],
        "variables": {
            "DOCKER_DRIVER": "overlay2"
        },
        ".service-template": {
            "image": "$BUILD_IMAGE",
            "before_script": [
                "cd services/$SERVICE_NAME",
                "echo Building service: $SERVICE_NAME"
            ],
            "variables": {
                "SERVICE_NAME": "",
                "BUILD_IMAGE": "alpine:latest"
            }
        }
    }
    
    # Generate jobs for each service
    for service in services_to_build:
        service_type = detect_service_type(service)
        build_image = get_build_image(service_type)
        
        # Build job
        matrix_pipeline[f"build-{service}"] = {
            "extends": ".service-template",
            "stage": "build",
            "variables": {
                "SERVICE_NAME": service,
                "BUILD_IMAGE": build_image
            },
            "script": generate_build_script(service_type, service),
            "artifacts": {
                "paths": [f"services/{service}/dist/", f"services/{service}/target/"],
                "expire_in": "1 hour"
            }
        }
        
        # Test job
        matrix_pipeline[f"test-{service}"] = {
            "extends": ".service-template",
            "stage": "test",
            "variables": {
                "SERVICE_NAME": service,
                "BUILD_IMAGE": build_image
            },
            "script": generate_test_script(service_type, service),
            "dependencies": [f"build-{service}"]
        }
        
        # Package job
        matrix_pipeline[f"package-{service}"] = {
            "stage": "package",
            "image": "docker:24",
            "services": ["docker:24-dind"],
            "variables": {
                "SERVICE_NAME": service
            },
            "script": [
                "docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY",
                f"cd services/{service}",
                f"docker build -t $CI_REGISTRY_IMAGE/{service}:$CI_COMMIT_SHA .",
                f"docker push $CI_REGISTRY_IMAGE/{service}:$CI_COMMIT_SHA"
            ],
            "dependencies": [f"test-{service}"]
        }
    
    return matrix_pipeline

def main():
    """Main function to generate service pipelines"""
    print("Generating service-specific pipelines...")
    
    # Load services matrix
    services_matrix = load_services_matrix()
    
    # Create output directory
    output_dir = Path("generated-pipelines")
    output_dir.mkdir(exist_ok=True)
    
    # Generate matrix-based pipeline
    matrix_pipeline = generate_matrix_pipeline(services_matrix)
    
    # Convert to YAML format (simplified)
    yaml_content = yaml_dump(matrix_pipeline)
    
    # Write pipeline file
    with open(output_dir / "build-pipeline.yml", "w") as f:
        f.write(yaml_content)
    
    print(f"Generated pipeline: {output_dir}/build-pipeline.yml")
    print(f"Services to build: {services_matrix['changed_services'] or 'all services'}")

def yaml_dump(data, indent=0):
    """Simple YAML dumper for pipeline generation"""
    yaml_str = ""
    
    for key, value in data.items():
        if isinstance(value, dict):
            yaml_str += "  " * indent + f"{key}:\n"
            yaml_str += yaml_dump(value, indent + 1)
        elif isinstance(value, list):
            yaml_str += "  " * indent + f"{key}:\n"
            for item in value:
                if isinstance(item, str):
                    yaml_str += "  " * (indent + 1) + f"- {item}\n"
                else:
                    yaml_str += "  " * (indent + 1) + f"- {item}\n"
        else:
            yaml_str += "  " * indent + f"{key}: {value}\n"
    
    return yaml_str

if __name__ == "__main__":
    main()

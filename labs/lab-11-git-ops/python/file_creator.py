#!/usr/bin/env python3
"""
File creator for GitLab CI/CD pipeline.
Creates sample application files when needed.
"""

import os
import logging
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from utils import Config, ensure_directory, print_subsection


class FileCreator:
    """Create sample application files."""
    
    def __init__(self, config: Config):
        """Initialize file creator with configuration."""
        self.config = config
        self.logger = logging.getLogger(__name__)
    
    def create_dockerfile(self) -> bool:
        """Create a sample Dockerfile."""
        dockerfile_content = '''# Sample Dockerfile for testing base image updates
FROM python:3.9-slim

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
EXPOSE 8000

# Set default command
CMD ["python", "app.py"]
'''
        
        try:
            ensure_directory(self.config.sample_app_dir)
            
            dockerfile_path = os.path.join(self.config.sample_app_dir, 'Dockerfile')
            with open(dockerfile_path, 'w') as f:
                f.write(dockerfile_content)
            
            print(f"✓ Created Dockerfile: {dockerfile_path}")
            self.logger.info(f"Dockerfile created: {dockerfile_path}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to create Dockerfile: {e}")
            print(f"✗ Failed to create Dockerfile: {e}")
            return False
    
    def create_python_app(self) -> bool:
        """Create a sample Python Flask application."""
        app_content = '''#!/usr/bin/env python3
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
'''
        
        try:
            ensure_directory(self.config.sample_app_dir)
            
            app_path = os.path.join(self.config.sample_app_dir, 'app.py')
            with open(app_path, 'w') as f:
                f.write(app_content)
            
            print(f"✓ Created Python app: {app_path}")
            self.logger.info(f"Python app created: {app_path}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to create Python app: {e}")
            print(f"✗ Failed to create Python app: {e}")
            return False
    
    def create_requirements_file(self) -> bool:
        """Create a requirements.txt file."""
        requirements_content = '''Flask==2.3.3
Werkzeug==2.3.7
'''
        
        try:
            ensure_directory(self.config.sample_app_dir)
            
            requirements_path = os.path.join(self.config.sample_app_dir, 'requirements.txt')
            with open(requirements_path, 'w') as f:
                f.write(requirements_content)
            
            print(f"✓ Created requirements file: {requirements_path}")
            self.logger.info(f"Requirements file created: {requirements_path}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to create requirements file: {e}")
            print(f"✗ Failed to create requirements file: {e}")
            return False
    
    def create_all_sample_files(self) -> bool:
        """
        Create all sample application files.
        
        Returns:
            True if all files were created successfully, False otherwise
        """
        print_subsection("Creating Sample Application Files")
        
        success = True
        
        # Create sample-app directory
        try:
            ensure_directory(self.config.sample_app_dir)
            print(f"✓ Ensured directory: {self.config.sample_app_dir}")
        except Exception as e:
            print(f"✗ Failed to create directory {self.config.sample_app_dir}: {e}")
            return False
        
        # Create Dockerfile
        if not self.create_dockerfile():
            success = False
        
        # Create Python application
        if not self.create_python_app():
            success = False
        
        # Create requirements file
        if not self.create_requirements_file():
            success = False
        
        if success:
            print("✅ All sample files created successfully!")
            self.logger.info("All sample files created successfully")
        else:
            print("❌ Some sample files failed to create")
            self.logger.error("Some sample files failed to create")
        
        return success
    
    def check_sample_files_exist(self) -> bool:
        """
        Check if all sample files exist.
        
        Returns:
            True if all sample files exist, False otherwise
        """
        required_files = [
            os.path.join(self.config.sample_app_dir, 'Dockerfile'),
            os.path.join(self.config.sample_app_dir, 'app.py'),
            os.path.join(self.config.sample_app_dir, 'requirements.txt')
        ]
        
        all_exist = True
        for filepath in required_files:
            if not os.path.exists(filepath):
                self.logger.debug(f"Missing sample file: {filepath}")
                all_exist = False
        
        return all_exist
    
    def list_created_files(self) -> None:
        """List all files in the sample app directory."""
        try:
            if not os.path.exists(self.config.sample_app_dir):
                print(f"Sample app directory does not exist: {self.config.sample_app_dir}")
                return
            
            files = os.listdir(self.config.sample_app_dir)
            if files:
                print(f"Files in {self.config.sample_app_dir}:")
                for file in sorted(files):
                    filepath = os.path.join(self.config.sample_app_dir, file)
                    size = os.path.getsize(filepath)
                    print(f"  - {file} ({size} bytes)")
            else:
                print(f"No files found in {self.config.sample_app_dir}")
                
        except Exception as e:
            print(f"Error listing files: {e}")
            self.logger.error(f"Error listing files: {e}")


def main():
    """Main function for standalone execution."""
    import sys
    from utils import setup_logging, exit_with_message
    
    setup_logging()
    
    config = Config()
    
    file_creator = FileCreator(config)
    
    # Check if files already exist
    if file_creator.check_sample_files_exist():
        print("✅ Sample files already exist")
        file_creator.list_created_files()
        return 0
    
    # Create all sample files
    success = file_creator.create_all_sample_files()
    
    if success:
        print("\n📁 Created sample files:")
        file_creator.list_created_files()
        return 0
    else:
        exit_with_message("Failed to create some sample files", 1)


if __name__ == "__main__":
    main()
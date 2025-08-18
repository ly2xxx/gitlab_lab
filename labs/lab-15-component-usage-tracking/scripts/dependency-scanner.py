#!/usr/bin/env python3
"""
Dependency Scanner

Automatically discovers GitLab CI component usage across projects by scanning
.gitlab-ci.yml files and detecting component/project includes.

Usage:
    python dependency-scanner.py scan-all
    python dependency-scanner.py scan --component helloworld
    python dependency-scanner.py scan-project --project-id 123
    python dependency-scanner.py report --output usage-report.json
"""

import json
import os
import sys
import argparse
import logging
import re
import yaml
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any, Set
from pathlib import Path

# Add parent directory to path for importing shared modules
sys.path.append(str(Path(__file__).parent.parent.parent / "lab-11-git-ops" / "python"))

try:
    from gitlab_api import GitLabAPI
    from utils import log_info, log_error, log_warn, log_debug
except ImportError:
    print("Error: Cannot import required modules. Ensure lab-11-git-ops is available.")
    sys.exit(1)


class ComponentUsagePattern:
    """Represents a detected component usage pattern."""
    
    def __init__(self, project_id: int, project_path: str, file_path: str, 
                 component_name: str, include_type: str, include_details: Dict[str, Any]):
        self.project_id = project_id
        self.project_path = project_path
        self.file_path = file_path
        self.component_name = component_name
        self.include_type = include_type  # 'component' or 'project'
        self.include_details = include_details
        self.detected_at = datetime.now(timezone.utc).isoformat()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "project_id": self.project_id,
            "project_path": self.project_path,
            "file_path": self.file_path,
            "component_name": self.component_name,
            "include_type": self.include_type,
            "include_details": self.include_details,
            "detected_at": self.detected_at
        }


class DependencyScanner:
    """Scans GitLab projects for component usage patterns."""
    
    def __init__(self, gitlab_api: GitLabAPI):
        """Initialize the dependency scanner.
        
        Args:
            gitlab_api: GitLab API instance
        """
        self.gitlab_api = gitlab_api
        
        # Set up logging
        logging.basicConfig(
            level=logging.DEBUG if os.getenv('DEBUG') else logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
        # Component include patterns
        self.component_pattern = re.compile(
            r'component:\s*([^@\s]+)(?:@([^\s]+))?',
            re.IGNORECASE
        )
        
        # Project include patterns  
        self.project_pattern = re.compile(
            r'project:\s*[\'"]?([^\s\'"]+)[\'"]?',
            re.IGNORECASE
        )
        
        # File pattern for project includes
        self.file_pattern = re.compile(
            r'file:\s*[\'"]?([^\s\'"]+)[\'"]?',
            re.IGNORECASE
        )
    
    def scan_all_projects(self, max_projects: int = 100) -> List[ComponentUsagePattern]:
        """Scan all accessible projects for component usage.
        
        Args:
            max_projects: Maximum number of projects to scan
            
        Returns:
            List of detected usage patterns
        """
        log_info("Starting comprehensive project scan")
        usage_patterns = []
        
        try:
            # Get list of projects (limit for performance)
            projects = self.gitlab_api.get_projects(per_page=50)
            
            if not projects:
                log_warn("No projects found or insufficient permissions")
                return usage_patterns
            
            scanned_count = 0
            for project in projects[:max_projects]:
                try:
                    project_id = project['id']
                    project_path = project['path_with_namespace']
                    
                    log_debug(f"Scanning project: {project_path}")
                    
                    patterns = self.scan_project(project_id, project_path)
                    usage_patterns.extend(patterns)
                    
                    scanned_count += 1
                    
                    if scanned_count % 10 == 0:
                        log_info(f"Scanned {scanned_count} projects, found {len(usage_patterns)} patterns")
                
                except Exception as e:
                    log_debug(f"Failed to scan project {project.get('path_with_namespace', 'unknown')}: {str(e)}")
                    continue
            
            log_info(f"✅ Scan complete: {scanned_count} projects scanned, {len(usage_patterns)} patterns found")
            return usage_patterns
        
        except Exception as e:
            log_error(f"Failed to scan projects: {str(e)}")
            return usage_patterns
    
    def scan_project(self, project_id: int, project_path: str = None) -> List[ComponentUsagePattern]:
        """Scan a specific project for component usage.
        
        Args:
            project_id: GitLab project ID
            project_path: Optional project path for logging
            
        Returns:
            List of detected usage patterns
        """
        usage_patterns = []
        
        try:
            if not project_path:
                project_info = self.gitlab_api.get_project(project_id)
                project_path = project_info.get('path_with_namespace', f'project-{project_id}')
            
            # Get .gitlab-ci.yml file
            ci_files = ['.gitlab-ci.yml', '.gitlab-ci.yaml']
            
            for ci_file in ci_files:
                try:
                    content = self.gitlab_api.get_file_content(project_id, ci_file, 'main')
                    if content:
                        patterns = self.analyze_ci_file(
                            project_id, project_path, ci_file, content
                        )
                        usage_patterns.extend(patterns)
                        break  # Found CI file, no need to check other names
                
                except Exception:
                    continue  # Try next file name
            
            # Also check for CI files in .gitlab/ci/ directory
            try:
                ci_dir_files = self.gitlab_api.list_directory_files(project_id, '.gitlab/ci', 'main')
                for file_info in ci_dir_files:
                    if file_info['name'].endswith(('.yml', '.yaml')):
                        file_path = f".gitlab/ci/{file_info['name']}"
                        try:
                            content = self.gitlab_api.get_file_content(project_id, file_path, 'main')
                            if content:
                                patterns = self.analyze_ci_file(
                                    project_id, project_path, file_path, content
                                )
                                usage_patterns.extend(patterns)
                        except Exception:
                            continue
            
            except Exception:
                pass  # Directory doesn't exist or not accessible
            
            return usage_patterns
        
        except Exception as e:
            log_debug(f"Failed to scan project {project_path}: {str(e)}")
            return usage_patterns
    
    def analyze_ci_file(self, project_id: int, project_path: str, 
                       file_path: str, content: str) -> List[ComponentUsagePattern]:
        """Analyze a CI file for component usage patterns.
        
        Args:
            project_id: GitLab project ID
            project_path: Project path
            file_path: Path to CI file
            content: File content
            
        Returns:
            List of detected usage patterns
        """
        usage_patterns = []
        
        try:
            # Parse YAML content
            try:
                yaml_data = yaml.safe_load(content)
            except yaml.YAMLError as e:
                log_debug(f"Invalid YAML in {project_path}/{file_path}: {str(e)}")
                return usage_patterns
            
            if not isinstance(yaml_data, dict):
                return usage_patterns
            
            # Look for include section
            includes = yaml_data.get('include', [])
            if not isinstance(includes, list):
                includes = [includes]
            
            for include_item in includes:
                if not isinstance(include_item, dict):
                    continue
                
                # Check for component includes
                if 'component' in include_item:
                    component_ref = include_item['component']
                    
                    # Parse component reference
                    # Format: host/group/project/component@version
                    parts = component_ref.split('/')
                    if len(parts) >= 4:
                        component_name = parts[-1].split('@')[0]
                        
                        pattern = ComponentUsagePattern(
                            project_id=project_id,
                            project_path=project_path,
                            file_path=file_path,
                            component_name=component_name,
                            include_type='component',
                            include_details={
                                'component_ref': component_ref,
                                'inputs': include_item.get('inputs', {}),
                                'version': component_ref.split('@')[1] if '@' in component_ref else 'latest'
                            }
                        )
                        usage_patterns.append(pattern)
                
                # Check for project includes that might reference component templates
                elif 'project' in include_item and 'file' in include_item:
                    file_ref = include_item['file']
                    
                    # Look for template files that might be components
                    if 'template' in file_ref.lower() or file_ref.startswith('templates/'):
                        # Extract potential component name from file path
                        component_name = self._extract_component_name_from_path(file_ref)
                        
                        if component_name:
                            pattern = ComponentUsagePattern(
                                project_id=project_id,
                                project_path=project_path,
                                file_path=file_path,
                                component_name=component_name,
                                include_type='project',
                                include_details={
                                    'project': include_item['project'],
                                    'file': file_ref,
                                    'ref': include_item.get('ref', 'main')
                                }
                            )
                            usage_patterns.append(pattern)
            
            return usage_patterns
        
        except Exception as e:
            log_debug(f"Failed to analyze CI file {project_path}/{file_path}: {str(e)}")
            return usage_patterns
    
    def scan_for_component(self, component_name: str, 
                          max_projects: int = 100) -> List[ComponentUsagePattern]:
        """Scan for usage of a specific component.
        
        Args:
            component_name: Name of component to search for
            max_projects: Maximum number of projects to scan
            
        Returns:
            List of usage patterns for the specified component
        """
        log_info(f"Scanning for component: {component_name}")
        
        all_patterns = self.scan_all_projects(max_projects)
        
        # Filter for specific component
        component_patterns = [
            pattern for pattern in all_patterns 
            if pattern.component_name == component_name
        ]
        
        log_info(f"Found {len(component_patterns)} usages of component '{component_name}'")
        return component_patterns
    
    def generate_usage_report(self, patterns: List[ComponentUsagePattern]) -> Dict[str, Any]:
        """Generate a comprehensive usage report.
        
        Args:
            patterns: List of usage patterns
            
        Returns:
            Report data dictionary
        """
        report = {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "total_patterns": len(patterns),
            "summary": {
                "components": {},
                "projects": {},
                "include_methods": {"component": 0, "project": 0}
            },
            "patterns": [pattern.to_dict() for pattern in patterns]
        }
        
        # Component summary
        component_usage = {}
        project_usage = {}
        
        for pattern in patterns:
            # Component stats
            comp_name = pattern.component_name
            if comp_name not in component_usage:
                component_usage[comp_name] = {
                    "total_usage": 0,
                    "projects": set(),
                    "include_methods": {"component": 0, "project": 0}
                }
            
            component_usage[comp_name]["total_usage"] += 1
            component_usage[comp_name]["projects"].add(pattern.project_path)
            component_usage[comp_name]["include_methods"][pattern.include_type] += 1
            
            # Project stats
            proj_path = pattern.project_path
            if proj_path not in project_usage:
                project_usage[proj_path] = {
                    "components": set(),
                    "total_includes": 0
                }
            
            project_usage[proj_path]["components"].add(comp_name)
            project_usage[proj_path]["total_includes"] += 1
            
            # Overall include method stats
            report["summary"]["include_methods"][pattern.include_type] += 1
        
        # Convert sets to lists and counts for JSON serialization
        for comp_name, stats in component_usage.items():
            report["summary"]["components"][comp_name] = {
                "total_usage": stats["total_usage"],
                "unique_projects": len(stats["projects"]),
                "projects": list(stats["projects"]),
                "include_methods": stats["include_methods"]
            }
        
        for proj_path, stats in project_usage.items():
            report["summary"]["projects"][proj_path] = {
                "unique_components": len(stats["components"]),
                "components": list(stats["components"]),
                "total_includes": stats["total_includes"]
            }
        
        return report
    
    def _extract_component_name_from_path(self, file_path: str) -> Optional[str]:
        """Extract component name from file path.
        
        Args:
            file_path: File path to analyze
            
        Returns:
            Component name if detectable, None otherwise
        """
        # Common patterns for component templates
        patterns = [
            r'templates/([^/]+)\.ya?ml$',  # templates/component.yml
            r'templates/([^/]+)/[^/]+\.ya?ml$',  # templates/component/template.yml
            r'([^/]+)-template\.ya?ml$',  # component-template.yml
            r'([^/]+)\.template\.ya?ml$'  # component.template.yml
        ]
        
        for pattern in patterns:
            match = re.search(pattern, file_path, re.IGNORECASE)
            if match:
                return match.group(1)
        
        return None


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(description="Component Dependency Scanner")
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Scan all projects command
    scan_all_parser = subparsers.add_parser('scan-all', help='Scan all accessible projects')
    scan_all_parser.add_argument('--max-projects', type=int, default=100, 
                                help='Maximum projects to scan')
    scan_all_parser.add_argument('--output', help='Output file for results')
    
    # Scan specific component command
    scan_parser = subparsers.add_parser('scan', help='Scan for specific component usage')
    scan_parser.add_argument('--component', required=True, help='Component name to search for')
    scan_parser.add_argument('--max-projects', type=int, default=100, 
                            help='Maximum projects to scan')
    scan_parser.add_argument('--output', help='Output file for results')
    
    # Scan specific project command
    project_parser = subparsers.add_parser('scan-project', help='Scan specific project')
    project_parser.add_argument('--project-id', required=True, type=int, 
                               help='GitLab project ID')
    project_parser.add_argument('--output', help='Output file for results')
    
    # Generate report command
    report_parser = subparsers.add_parser('report', help='Generate usage report from scan results')
    report_parser.add_argument('--input', help='Input file with scan results')
    report_parser.add_argument('--output', default='usage-report.json', 
                              help='Output file for report')
    
    # Validate registry command
    validate_parser = subparsers.add_parser('validate-registry', 
                                           help='Validate component registry against actual usage')
    validate_parser.add_argument('--registry-project-id', required=True, type=int,
                                help='Registry project ID')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # Get environment variables
    gitlab_url = os.getenv('GITLAB_URL', 'https://gitlab.com')
    gitlab_token = os.getenv('GITLAB_TOKEN')
    
    if not gitlab_token:
        log_error("GITLAB_TOKEN environment variable is required")
        sys.exit(1)
    
    # Initialize GitLab API and scanner
    try:
        gitlab_api = GitLabAPI(gitlab_url, gitlab_token)
        scanner = DependencyScanner(gitlab_api)
    except Exception as e:
        log_error(f"Failed to initialize GitLab API: {str(e)}")
        sys.exit(1)
    
    # Execute commands
    try:
        if args.command == 'scan-all':
            patterns = scanner.scan_all_projects(args.max_projects)
            
            if args.output:
                with open(args.output, 'w') as f:
                    json.dump([p.to_dict() for p in patterns], f, indent=2)
                log_info(f"Results saved to {args.output}")
            else:
                # Print summary
                print(f"\n📊 Scan Results:")
                print(f"Total patterns found: {len(patterns)}")
                
                # Group by component
                components = {}
                for pattern in patterns:
                    comp = pattern.component_name
                    if comp not in components:
                        components[comp] = []
                    components[comp].append(pattern)
                
                for comp, comp_patterns in components.items():
                    projects = set(p.project_path for p in comp_patterns)
                    print(f"\n{comp}: {len(comp_patterns)} usages across {len(projects)} projects")
                    for project in sorted(projects):
                        print(f"  - {project}")
        
        elif args.command == 'scan':
            patterns = scanner.scan_for_component(args.component, args.max_projects)
            
            if args.output:
                with open(args.output, 'w') as f:
                    json.dump([p.to_dict() for p in patterns], f, indent=2)
                log_info(f"Results saved to {args.output}")
            else:
                print(f"\n📊 Usage of component '{args.component}':")
                print(f"Total usages: {len(patterns)}")
                
                projects = set(p.project_path for p in patterns)
                print(f"Unique projects: {len(projects)}")
                
                for pattern in patterns:
                    print(f"  - {pattern.project_path} ({pattern.include_type})")
        
        elif args.command == 'scan-project':
            patterns = scanner.scan_project(args.project_id)
            
            if args.output:
                with open(args.output, 'w') as f:
                    json.dump([p.to_dict() for p in patterns], f, indent=2)
                log_info(f"Results saved to {args.output}")
            else:
                print(f"\n📊 Project scan results:")
                print(f"Patterns found: {len(patterns)}")
                
                for pattern in patterns:
                    print(f"  - {pattern.component_name} ({pattern.include_type}) in {pattern.file_path}")
        
        elif args.command == 'report':
            # Load scan results
            if args.input:
                with open(args.input, 'r') as f:
                    pattern_data = json.load(f)
                
                patterns = []
                for data in pattern_data:
                    pattern = ComponentUsagePattern(
                        data['project_id'], data['project_path'], data['file_path'],
                        data['component_name'], data['include_type'], data['include_details']
                    )
                    patterns.append(pattern)
            else:
                log_info("No input file specified, performing fresh scan")
                patterns = scanner.scan_all_projects()
            
            # Generate report
            report = scanner.generate_usage_report(patterns)
            
            with open(args.output, 'w') as f:
                json.dump(report, f, indent=2)
            
            log_info(f"Report generated: {args.output}")
            
            # Print summary
            summary = report['summary']
            print(f"\n📊 Usage Report Summary:")
            print(f"Total patterns: {report['total_patterns']}")
            print(f"Unique components: {len(summary['components'])}")
            print(f"Unique projects: {len(summary['projects'])}")
            print(f"Include methods: {summary['include_methods']}")
        
        elif args.command == 'validate-registry':
            # This would integrate with the registry manager
            log_info("Registry validation not yet implemented")
            # TODO: Load registry data and compare with scan results
    
    except Exception as e:
        log_error(f"Command failed: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
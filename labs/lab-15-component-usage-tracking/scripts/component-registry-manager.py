#!/usr/bin/env python3
"""
Component Registry Manager

Manages a GitLab-based registry for tracking CI/CD component dependencies.
Provides functionality to register components, track consumers, and generate analytics.

Usage:
    python component-registry-manager.py init
    python component-registry-manager.py register-component --name hello --project group/repo
    python component-registry-manager.py add-consumer --component hello --consumer-project group/consumer
    python component-registry-manager.py list-consumers --component hello
"""

import json
import os
import sys
import argparse
import logging
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any
from pathlib import Path

# Add parent directory to path for importing shared modules
# sys.path.append(str(Path(__file__).parent.parent.parent / "lab-11-git-ops" / "python"))
sys.path.append(str(Path(__file__).parent.parent.parent / "labs" / "lab-11-git-ops" / "python"))

try:
    from gitlab_api import GitLabAPI
    from utils import log_info, log_error, log_warn, log_debug
except ImportError:
    print("Error: Cannot import required modules. Ensure lab-11-git-ops is available.")
    sys.exit(1)


class ComponentRegistry:
    """Manages component registry data using GitLab repository as backend."""
    
    def __init__(self, gitlab_api: GitLabAPI, registry_project_id: str):
        """Initialize the component registry.
        
        Args:
            gitlab_api: GitLab API instance
            registry_project_id: Project ID where registry data is stored
        """
        self.gitlab_api = gitlab_api
        self.registry_project_id = registry_project_id
        self.components_file = "registry/components.json"
        self.consumers_dir = "registry/consumers"
        
        # Set up logging
        logging.basicConfig(
            level=logging.DEBUG if os.getenv('DEBUG') else logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
    
    def init_registry(self) -> bool:
        """Initialize the registry structure."""
        try:
            log_info("Initializing component registry")
            
            # Create initial components.json if it doesn't exist
            components_data = {
                "version": "1.0.0",
                "created_at": datetime.now(timezone.utc).isoformat(),
                "components": {},
                "metadata": {
                    "total_components": 0,
                    "total_consumers": 0,
                    "last_updated": datetime.now(timezone.utc).isoformat()
                }
            }
            
            # Check if components.json already exists
            existing_file = self.gitlab_api.get_file_content(
                self.registry_project_id, 
                self.components_file, 
                "main"
            )
            
            if existing_file is None:
                # Create initial file
                self.gitlab_api.create_file(
                    self.registry_project_id,
                    self.components_file,
                    json.dumps(components_data, indent=2),
                    "Initialize component registry",
                    "main"
                )
                log_info("✅ Registry initialized successfully")
            else:
                log_info("✅ Registry already exists")
            
            return True
            
        except Exception as e:
            log_error(f"Failed to initialize registry: {str(e)}")
            return False
    
    def register_component(self, name: str, project: str, path: str, 
                          version: str, description: str = "", 
                          maintainer: str = "") -> bool:
        """Register a new component in the registry.
        
        Args:
            name: Component name
            project: GitLab project path (group/project)
            path: Path to component template in project
            version: Component version
            description: Optional description
            maintainer: Optional maintainer email
            
        Returns:
            True if successful, False otherwise
        """
        try:
            log_info(f"Registering component: {name}")
            
            # Load existing components
            components_content = self.gitlab_api.get_file_content(
                self.registry_project_id,
                self.components_file,
                "main"
            )
            
            if components_content is None:
                log_error("Registry not initialized. Run 'init' command first.")
                return False
            
            components_data = json.loads(components_content)
            
            # Create component entry
            component_data = {
                "name": name,
                "project": project,
                "path": path,
                "current_version": version,
                "description": description,
                "maintainer": maintainer,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "updated_at": datetime.now(timezone.utc).isoformat(),
                "versions": [
                    {
                        "version": version,
                        "released_at": datetime.now(timezone.utc).isoformat(),
                        "changes": "Initial registration",
                        "breaking_changes": False
                    }
                ],
                "usage_stats": {
                    "total_consumers": 0,
                    "active_consumers": 0,
                    "last_scan": None
                }
            }
            
            # Add to registry
            components_data["components"][name] = component_data
            components_data["metadata"]["total_components"] = len(components_data["components"])
            components_data["metadata"]["last_updated"] = datetime.now(timezone.utc).isoformat()
            
            # Update file
            self.gitlab_api.update_file(
                self.registry_project_id,
                self.components_file,
                json.dumps(components_data, indent=2),
                f"Register component: {name} v{version}",
                "main"
            )
            
            # Create consumer file for this component
            consumer_file = f"{self.consumers_dir}/{name}.json"
            consumer_data = {
                "component": name,
                "consumers": [],
                "last_updated": datetime.now(timezone.utc).isoformat()
            }
            
            self.gitlab_api.create_file(
                self.registry_project_id,
                consumer_file,
                json.dumps(consumer_data, indent=2),
                f"Initialize consumer registry for {name}",
                "main"
            )
            
            log_info(f"✅ Component {name} registered successfully")
            return True
            
        except Exception as e:
            log_error(f"Failed to register component {name}: {str(e)}")
            return False
    
    def add_consumer(self, component: str, consumer_project: str, 
                    contact: str, version_used: str = "", 
                    include_method: str = "unknown") -> bool:
        """Add a consumer to a component's registry.
        
        Args:
            component: Component name
            consumer_project: Consumer project path
            contact: Contact email for consumer
            version_used: Version of component being used
            include_method: How component is included (component/project)
            
        Returns:
            True if successful, False otherwise
        """
        try:
            log_info(f"Adding consumer {consumer_project} to component {component}")
            
            # Load consumer data
            consumer_file = f"{self.consumers_dir}/{component}.json"
            consumer_content = self.gitlab_api.get_file_content(
                self.registry_project_id,
                consumer_file,
                "main"
            )
            
            if consumer_content is None:
                log_error(f"Component {component} not found in registry")
                return False
            
            consumer_data = json.loads(consumer_content)
            
            # Check if consumer already exists
            existing_consumer = None
            for i, consumer in enumerate(consumer_data["consumers"]):
                if consumer["project_path"] == consumer_project:
                    existing_consumer = i
                    break
            
            # Create consumer entry
            consumer_entry = {
                "project_path": consumer_project,
                "contact": contact,
                "version_used": version_used,
                "include_method": include_method,
                "registered_at": datetime.now(timezone.utc).isoformat(),
                "last_seen": datetime.now(timezone.utc).isoformat(),
                "status": "active"
            }
            
            if existing_consumer is not None:
                # Update existing consumer
                consumer_data["consumers"][existing_consumer] = consumer_entry
                log_info(f"Updated existing consumer: {consumer_project}")
            else:
                # Add new consumer
                consumer_data["consumers"].append(consumer_entry)
                log_info(f"Added new consumer: {consumer_project}")
            
            consumer_data["last_updated"] = datetime.now(timezone.utc).isoformat()
            
            # Update consumer file
            self.gitlab_api.update_file(
                self.registry_project_id,
                consumer_file,
                json.dumps(consumer_data, indent=2),
                f"Add consumer {consumer_project} to {component}",
                "main"
            )
            
            # Update component usage stats
            self._update_component_stats(component, len(consumer_data["consumers"]))
            
            log_info(f"✅ Consumer {consumer_project} added to {component}")
            return True
            
        except Exception as e:
            log_error(f"Failed to add consumer {consumer_project} to {component}: {str(e)}")
            return False
    
    def list_consumers(self, component: str) -> List[Dict[str, Any]]:
        """List all consumers of a component.
        
        Args:
            component: Component name
            
        Returns:
            List of consumer data dictionaries
        """
        try:
            consumer_file = f"{self.consumers_dir}/{component}.json"
            consumer_content = self.gitlab_api.get_file_content(
                self.registry_project_id,
                consumer_file,
                "main"
            )
            
            if consumer_content is None:
                log_error(f"Component {component} not found")
                return []
            
            consumer_data = json.loads(consumer_content)
            return consumer_data["consumers"]
            
        except Exception as e:
            log_error(f"Failed to list consumers for {component}: {str(e)}")
            return []
    
    def get_component_info(self, component: str) -> Optional[Dict[str, Any]]:
        """Get detailed information about a component.
        
        Args:
            component: Component name
            
        Returns:
            Component data dictionary or None if not found
        """
        try:
            components_content = self.gitlab_api.get_file_content(
                self.registry_project_id,
                self.components_file,
                "main"
            )
            
            if components_content is None:
                return None
            
            components_data = json.loads(components_content)
            return components_data["components"].get(component)
            
        except Exception as e:
            log_error(f"Failed to get component info for {component}: {str(e)}")
            return None
    
    def generate_analytics(self, component: Optional[str] = None) -> Dict[str, Any]:
        """Generate analytics for components.
        
        Args:
            component: Optional specific component name
            
        Returns:
            Analytics data dictionary
        """
        try:
            log_info("Generating analytics")
            
            components_content = self.gitlab_api.get_file_content(
                self.registry_project_id,
                self.components_file,
                "main"
            )
            
            if components_content is None:
                return {}
            
            components_data = json.loads(components_content)
            
            if component:
                # Analytics for specific component
                comp_data = components_data["components"].get(component)
                if not comp_data:
                    return {}
                
                consumers = self.list_consumers(component)
                
                analytics = {
                    "component": component,
                    "total_consumers": len(consumers),
                    "active_consumers": len([c for c in consumers if c["status"] == "active"]),
                    "version_distribution": {},
                    "include_methods": {},
                    "recent_registrations": []
                }
                
                # Version distribution
                for consumer in consumers:
                    version = consumer.get("version_used", "unknown")
                    analytics["version_distribution"][version] = analytics["version_distribution"].get(version, 0) + 1
                
                # Include method distribution
                for consumer in consumers:
                    method = consumer.get("include_method", "unknown")
                    analytics["include_methods"][method] = analytics["include_methods"].get(method, 0) + 1
                
                # Recent registrations (last 30 days)
                cutoff = datetime.now(timezone.utc).replace(day=1)  # Simplified for demo
                for consumer in consumers:
                    reg_date = datetime.fromisoformat(consumer["registered_at"].replace('Z', '+00:00'))
                    if reg_date > cutoff:
                        analytics["recent_registrations"].append({
                            "project": consumer["project_path"],
                            "date": consumer["registered_at"]
                        })
                
                return analytics
            
            else:
                # Overall analytics
                total_consumers = 0
                active_consumers = 0
                
                for comp_name in components_data["components"]:
                    consumers = self.list_consumers(comp_name)
                    total_consumers += len(consumers)
                    active_consumers += len([c for c in consumers if c["status"] == "active"])
                
                analytics = {
                    "overview": {
                        "total_components": len(components_data["components"]),
                        "total_consumers": total_consumers,
                        "active_consumers": active_consumers,
                        "registry_created": components_data.get("created_at"),
                        "last_updated": components_data["metadata"]["last_updated"]
                    },
                    "components": {}
                }
                
                # Per-component summary
                for comp_name, comp_data in components_data["components"].items():
                    consumers = self.list_consumers(comp_name)
                    analytics["components"][comp_name] = {
                        "current_version": comp_data["current_version"],
                        "total_consumers": len(consumers),
                        "active_consumers": len([c for c in consumers if c["status"] == "active"]),
                        "last_updated": comp_data["updated_at"]
                    }
                
                return analytics
            
        except Exception as e:
            log_error(f"Failed to generate analytics: {str(e)}")
            return {}
    
    def _update_component_stats(self, component: str, consumer_count: int):
        """Update component usage statistics."""
        try:
            components_content = self.gitlab_api.get_file_content(
                self.registry_project_id,
                self.components_file,
                "main"
            )
            
            if components_content is None:
                return
            
            components_data = json.loads(components_content)
            
            if component in components_data["components"]:
                components_data["components"][component]["usage_stats"]["total_consumers"] = consumer_count
                components_data["components"][component]["usage_stats"]["last_scan"] = datetime.now(timezone.utc).isoformat()
                components_data["components"][component]["updated_at"] = datetime.now(timezone.utc).isoformat()
                components_data["metadata"]["last_updated"] = datetime.now(timezone.utc).isoformat()
                
                self.gitlab_api.update_file(
                    self.registry_project_id,
                    self.components_file,
                    json.dumps(components_data, indent=2),
                    f"Update stats for component {component}",
                    "main"
                )
        
        except Exception as e:
            log_error(f"Failed to update component stats: {str(e)}")


def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(description="Component Registry Manager")
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Init command
    init_parser = subparsers.add_parser('init', help='Initialize the registry')
    
    # Register component command
    register_parser = subparsers.add_parser('register-component', help='Register a new component')
    register_parser.add_argument('--name', required=True, help='Component name')
    register_parser.add_argument('--project', required=True, help='GitLab project path')
    register_parser.add_argument('--path', required=True, help='Path to component template')
    register_parser.add_argument('--version', required=True, help='Component version')
    register_parser.add_argument('--description', default='', help='Component description')
    register_parser.add_argument('--maintainer', default='', help='Maintainer email')
    
    # Add consumer command
    consumer_parser = subparsers.add_parser('add-consumer', help='Add consumer to component')
    consumer_parser.add_argument('--component', required=True, help='Component name')
    consumer_parser.add_argument('--consumer-project', required=True, help='Consumer project path')
    consumer_parser.add_argument('--contact', required=True, help='Contact email')
    consumer_parser.add_argument('--version-used', default='', help='Version being used')
    consumer_parser.add_argument('--include-method', default='unknown', help='Include method')
    
    # List consumers command
    list_parser = subparsers.add_parser('list-consumers', help='List component consumers')
    list_parser.add_argument('--component', required=True, help='Component name')
    
    # Analytics command
    analytics_parser = subparsers.add_parser('analytics', help='Generate analytics')
    analytics_parser.add_argument('--component', help='Specific component (optional)')
    analytics_parser.add_argument('--format', choices=['json', 'table'], default='table', help='Output format')
    
    # Component info command
    info_parser = subparsers.add_parser('info', help='Get component information')
    info_parser.add_argument('--component', required=True, help='Component name')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # Get environment variables
    gitlab_url = os.getenv('GITLAB_URL', 'https://gitlab.com')
    gitlab_token = os.getenv('GITLAB_TOKEN')
    registry_project_id = os.getenv('REGISTRY_PROJECT_ID')
    
    if not gitlab_token:
        log_error("GITLAB_TOKEN environment variable is required")
        sys.exit(1)
    
    if not registry_project_id:
        log_error("REGISTRY_PROJECT_ID environment variable is required")
        sys.exit(1)
    
    # Initialize GitLab API and registry
    try:
        gitlab_api = GitLabAPI(gitlab_url, gitlab_token)
        registry = ComponentRegistry(gitlab_api, registry_project_id)
    except Exception as e:
        log_error(f"Failed to initialize GitLab API: {str(e)}")
        sys.exit(1)
    
    # Execute commands
    try:
        if args.command == 'init':
            success = registry.init_registry()
            sys.exit(0 if success else 1)
        
        elif args.command == 'register-component':
            success = registry.register_component(
                args.name, args.project, args.path, args.version,
                args.description, args.maintainer
            )
            sys.exit(0 if success else 1)
        
        elif args.command == 'add-consumer':
            success = registry.add_consumer(
                args.component, args.consumer_project, args.contact,
                args.version_used, args.include_method
            )
            sys.exit(0 if success else 1)
        
        elif args.command == 'list-consumers':
            consumers = registry.list_consumers(args.component)
            if consumers:
                log_info(f"Consumers for component '{args.component}':")
                for consumer in consumers:
                    print(f"  - {consumer['project_path']} (v{consumer['version_used']}) - {consumer['contact']}")
            else:
                log_info(f"No consumers found for component '{args.component}'")
        
        elif args.command == 'analytics':
            analytics = registry.generate_analytics(args.component)
            if args.format == 'json':
                print(json.dumps(analytics, indent=2))
            else:
                # Table format
                if args.component:
                    comp = args.component
                    print(f"\n📊 Analytics for component: {comp}")
                    print(f"Total consumers: {analytics.get('total_consumers', 0)}")
                    print(f"Active consumers: {analytics.get('active_consumers', 0)}")
                    print(f"\nVersion distribution:")
                    for version, count in analytics.get('version_distribution', {}).items():
                        print(f"  {version}: {count}")
                else:
                    overview = analytics.get('overview', {})
                    print(f"\n📊 Registry Overview")
                    print(f"Total components: {overview.get('total_components', 0)}")
                    print(f"Total consumers: {overview.get('total_consumers', 0)}")
                    print(f"Active consumers: {overview.get('active_consumers', 0)}")
                    print(f"\nComponent summary:")
                    for comp, data in analytics.get('components', {}).items():
                        print(f"  {comp}: {data['total_consumers']} consumers (v{data['current_version']})")
        
        elif args.command == 'info':
            info = registry.get_component_info(args.component)
            if info:
                print(f"\n📋 Component: {args.component}")
                print(f"Project: {info['project']}")
                print(f"Path: {info['path']}")
                print(f"Current version: {info['current_version']}")
                print(f"Description: {info['description']}")
                print(f"Maintainer: {info['maintainer']}")
                print(f"Created: {info['created_at']}")
                print(f"Updated: {info['updated_at']}")
                print(f"Total consumers: {info['usage_stats']['total_consumers']}")
            else:
                log_error(f"Component '{args.component}' not found")
                sys.exit(1)
    
    except Exception as e:
        log_error(f"Command failed: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
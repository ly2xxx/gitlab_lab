"""
Publish Markdown files to Confluence
"""
import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from atlassian import Confluence
import markdown

# Load environment variables
load_dotenv()

CONFLUENCE_URL = os.getenv('CONFLUENCE_URL')
CONFLUENCE_USERNAME = os.getenv('CONFLUENCE_USERNAME')
CONFLUENCE_API_TOKEN = os.getenv('CONFLUENCE_API_TOKEN')
CONFLUENCE_SPACE_KEY = os.getenv('CONFLUENCE_SPACE_KEY')
CONFLUENCE_PARENT_PAGE_ID = os.getenv('CONFLUENCE_PARENT_PAGE_ID')


def validate_config():
    """Validate required environment variables"""
    required = {
        'CONFLUENCE_URL': CONFLUENCE_URL,
        'CONFLUENCE_USERNAME': CONFLUENCE_USERNAME,
        'CONFLUENCE_API_TOKEN': CONFLUENCE_API_TOKEN,
        'CONFLUENCE_SPACE_KEY': CONFLUENCE_SPACE_KEY,
    }
    
    missing = [key for key, value in required.items() if not value or value.startswith('your-')]
    
    if missing:
        print("❌ Missing or invalid configuration:")
        for key in missing:
            print(f"   - {key}")
        print("\nPlease update your .env file with valid credentials.")
        return False
    
    return True


def markdown_to_confluence_html(md_content):
    """Convert markdown to Confluence-compatible HTML"""
    # Convert markdown to HTML with extensions
    html = markdown.markdown(
        md_content,
        extensions=[
            'tables',
            'fenced_code',
            'codehilite',
            'nl2br',
            'sane_lists'
        ]
    )
    return html


def publish_to_confluence(markdown_file, page_title=None):
    """Publish a markdown file to Confluence"""
    
    if not validate_config():
        return False
    
    # Read markdown file
    md_path = Path(markdown_file)
    if not md_path.exists():
        print(f"❌ File not found: {markdown_file}")
        return False
    
    print(f"📖 Reading: {md_path.name}")
    with open(md_path, 'r', encoding='utf-8') as f:
        md_content = f.read()
    
    # Use filename as title if not provided
    if not page_title:
        page_title = md_path.stem.replace('-', ' ').replace('_', ' ').title()
    
    print(f"📝 Converting markdown to HTML...")
    html_content = markdown_to_confluence_html(md_content)
    
    # Connect to Confluence
    print(f"🔗 Connecting to Confluence...")
    confluence = Confluence(
        url=CONFLUENCE_URL,
        username=CONFLUENCE_USERNAME,
        password=CONFLUENCE_API_TOKEN
    )
    
    # Check if page exists
    print(f"🔍 Checking if page '{page_title}' exists...")
    existing_page = confluence.get_page_by_title(
        space=CONFLUENCE_SPACE_KEY,
        title=page_title
    )
    
    if existing_page:
        print(f"📄 Page exists - updating...")
        page_id = existing_page['id']
        confluence.update_page(
            page_id=page_id,
            title=page_title,
            body=html_content
        )
        page_url = f"{CONFLUENCE_URL}/wiki/spaces/{CONFLUENCE_SPACE_KEY}/pages/{page_id}"
        print(f"✅ Page updated successfully!")
    else:
        print(f"📄 Creating new page...")
        result = confluence.create_page(
            space=CONFLUENCE_SPACE_KEY,
            title=page_title,
            body=html_content,
            parent_id=CONFLUENCE_PARENT_PAGE_ID if CONFLUENCE_PARENT_PAGE_ID else None
        )
        page_id = result['id']
        page_url = f"{CONFLUENCE_URL}/wiki/spaces/{CONFLUENCE_SPACE_KEY}/pages/{page_id}"
        print(f"✅ Page created successfully!")
    
    print(f"🔗 URL: {page_url}")
    return True


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python publish.py <markdown-file> [page-title]")
        print("\nExample:")
        print("  python publish.py README.md")
        print("  python publish.py docs/api.md 'API Documentation'")
        sys.exit(1)
    
    markdown_file = sys.argv[1]
    page_title = sys.argv[2] if len(sys.argv) > 2 else None
    
    success = publish_to_confluence(markdown_file, page_title)
    sys.exit(0 if success else 1)

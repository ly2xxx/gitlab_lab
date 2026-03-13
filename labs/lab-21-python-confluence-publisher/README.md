# Lab 21: Python Confluence Publisher

Publish Markdown files to Confluence Cloud using Python.

## Setup

### 1. Install Dependencies

```bash
cd C:\code\gitlab_lab\labs\lab-21-python-confluence-publisher
pip install -r requirements.txt
```

### 2. Get Confluence API Token

1. Go to https://id.atlassian.com/manage-profile/security/api-tokens
2. Click **Create API token**
3. Give it a name (e.g., "Python Publisher")
4. Copy the token

### 3. Configure `.env` File

Edit `.env` and fill in your details:

```bash
CONFLUENCE_URL=https://your-domain.atlassian.net
CONFLUENCE_USERNAME=your-email@example.com
CONFLUENCE_API_TOKEN=your-api-token-here
CONFLUENCE_SPACE_KEY=YOUR_SPACE_KEY
CONFLUENCE_PARENT_PAGE_ID=123456  # Optional
```

**How to find your Space Key:**
- Go to your Confluence space
- Look at the URL: `https://your-domain.atlassian.net/wiki/spaces/SPACEKEY/...`
- The `SPACEKEY` part is what you need

**How to find Parent Page ID (optional):**
- Open the parent page in Confluence
- Click the "..." menu → "Page Information"
- Look at the URL: `https://your-domain.atlassian.net/wiki/pages/123456/...`
- The number is the page ID

## Usage

### Publish a Markdown File

```bash
python publish.py path/to/your-file.md
```

### Publish with Custom Title

```bash
python publish.py path/to/your-file.md "Custom Page Title"
```

### Examples

```bash
# Publish README
python publish.py README.md

# Publish with custom title
python publish.py docs/api-guide.md "API Documentation"

# Publish from different directory
python publish.py C:\projects\my-docs\architecture.md
```

## Features

- ✅ Converts Markdown to Confluence HTML
- ✅ Creates new pages or updates existing ones
- ✅ Supports tables, code blocks, lists
- ✅ Auto-detects page title from filename
- ✅ Safe credential storage via .env

## Supported Markdown

- Headers (h1-h6)
- **Bold**, *italic*, ~~strikethrough~~
- Lists (ordered/unordered)
- Code blocks with syntax highlighting
- Tables
- Links and images
- Blockquotes

## Troubleshooting

### "❌ Missing or invalid configuration"
- Check your `.env` file
- Make sure you've replaced all `your-*` placeholders
- Verify API token is valid

### "Page not found" or 404 errors
- Verify `CONFLUENCE_SPACE_KEY` is correct
- Check you have permissions to the space
- Try visiting the space URL in your browser first

### Authentication errors
- Regenerate your API token
- Make sure username is your full email address
- Check URL doesn't have trailing slashes

## Next Steps

- Add image upload support
- Batch publish multiple files
- Watch folder for changes
- Add table of contents generation

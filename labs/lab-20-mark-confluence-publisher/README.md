# Mark - Markdown to Confluence Publisher Lab

**Learn how to publish markdown documents directly to Confluence using the `mark` CLI tool.**

---

## 📋 What is Mark?

**mark** is a CLI tool that converts and publishes markdown files to Atlassian Confluence.

**Features:**
- ✅ Convert markdown → Confluence format automatically
- ✅ Update existing pages or create new ones
- ✅ Support for images, tables, code blocks, diagrams
- ✅ CI/CD friendly (perfect for GitLab/GitHub Actions)
- ✅ Bulk publishing with hierarchy support

**GitHub:** https://github.com/kovetskiy/mark

---

## 🚀 Quick Start

### 1. Install mark

```bash
# Option A: Download binary (recommended)
# Windows (PowerShell)
Invoke-WebRequest -Uri "https://github.com/kovetskiy/mark/releases/latest/download/mark.exe" -OutFile "mark.exe"

# Linux/macOS
curl -LO https://github.com/kovetskiy/mark/releases/latest/download/mark
chmod +x mark

# Option B: Install via Go (if you have Go installed)
go install github.com/kovetskiy/mark@latest
```

### 2. Set up Confluence credentials

Create `.env` file (see `.env.template`):

```bash
CONFLUENCE_URL="https://your-company.atlassian.net"
CONFLUENCE_USERNAME="your.email@company.com"
CONFLUENCE_API_TOKEN="your_api_token"
CONFLUENCE_SPACE="DOCS"  # Your space key
```

**Get API token:** https://id.atlassian.com/manage-profile/security/api-tokens

### 3. Test with sample document

```bash
# PowerShell
.\publish.ps1 sample.md

# Bash
bash publish.sh sample.md
```

---

## 📁 Lab Files

```
mark-confluence-publisher/
├── README.md              This file
├── SETUP.md               Detailed setup guide
├── .env.template          Environment variables template
├── publish.sh             Bash publishing script
├── publish.ps1            PowerShell publishing script
├── sample.md              Sample markdown document
├── examples/
│   ├── basic-doc.md       Simple document example
│   ├── with-images.md     Document with images
│   ├── with-diagrams.md   Mermaid diagrams
│   └── bulk-publish/      Folder structure for bulk publishing
└── tips-and-tricks.md     Advanced usage patterns
```

---

## 🎯 Basic Usage

### Publish a New Page

```bash
mark \
  --file my-document.md \
  --url https://your-company.atlassian.net \
  --space DOCS \
  --parent "Parent Page Title" \
  --username your.email@company.com \
  --password YOUR_API_TOKEN
```

### Update an Existing Page

**Method 1: By Page ID**
```bash
mark \
  --file my-document.md \
  --url https://your-company.atlassian.net \
  --page-id 123456789 \
  --username your.email@company.com \
  --password YOUR_API_TOKEN
```

**Method 2: By Title** (mark will find and update)
```bash
mark \
  --file my-document.md \
  --url https://your-company.atlassian.net \
  --space DOCS \
  --title "My Document Title" \
  --username your.email@company.com \
  --password YOUR_API_TOKEN
```

---

## 🔧 Environment Variables

Instead of passing credentials every time, use environment variables:

```bash
# Set once
export CONFLUENCE_URL="https://your-company.atlassian.net"
export CONFLUENCE_USERNAME="your.email@company.com"
export CONFLUENCE_PASSWORD="your_api_token"

# Then just use:
mark --file my-document.md --space DOCS
```

---

## 📝 Markdown Features Supported

### Headers
```markdown
# H1 - Page Title
## H2 - Section
### H3 - Subsection
```

### Text Formatting
```markdown
**Bold** _Italic_ ~~Strikethrough~~ `Code`
```

### Lists
```markdown
- Bullet list
  - Nested item

1. Numbered list
2. Another item
```

### Code Blocks
````markdown
```python
def hello():
    print("Hello, Confluence!")
```
````

### Tables
```markdown
| Column 1 | Column 2 |
|----------|----------|
| Data 1   | Data 2   |
```

### Images
```markdown
![Alt text](./images/diagram.png)
![External](https://example.com/image.jpg)
```

### Links
```markdown
[Link text](https://example.com)
[Internal page](confluence://page-title)
```

---

## 🎨 Advanced Features

### 1. Frontmatter (Page Metadata)

Add YAML frontmatter to your markdown:

```markdown
---
title: My Document Title
space: DOCS
parent: Parent Page
labels: [documentation, api, important]
---

# Content starts here
```

### 2. Confluence Macros

Insert Confluence macros directly:

```markdown
<!-- ac:note -->
This is a note macro!
<!-- /ac:note -->

<!-- ac:code -->
def example():
    pass
<!-- /ac:code -->
```

### 3. Mermaid Diagrams

```markdown
\`\`\`mermaid
graph TD
    A[Start] --> B[Process]
    B --> C[End]
\`\`\`
```

### 4. Bulk Publishing

Publish entire folder hierarchy:

```bash
mark \
  --directory ./docs \
  --space DOCS \
  --username your.email@company.com \
  --password YOUR_API_TOKEN
```

**Folder structure:**
```
docs/
├── index.md          → Root page
├── section1/
│   ├── index.md      → Section 1 parent
│   ├── page1.md      → Child page
│   └── page2.md      → Child page
└── section2/
    └── index.md      → Section 2 parent
```

---

## 🔐 Security Best Practices

### 1. Never Commit Credentials

Add to `.gitignore`:
```
.env
*.token
credentials.txt
```

### 2. Use Environment Variables

**PowerShell:**
```powershell
$env:CONFLUENCE_PASSWORD = Read-Host -AsSecureString "API Token"
```

**Bash:**
```bash
read -s CONFLUENCE_PASSWORD
export CONFLUENCE_PASSWORD
```

### 3. Use Scoped API Tokens

- Create tokens with minimal required permissions
- Rotate tokens regularly
- Revoke tokens when no longer needed

---

## 🏗️ CI/CD Integration

### GitLab CI Example

```yaml
publish-to-confluence:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache curl
    - curl -LO https://github.com/kovetskiy/mark/releases/latest/download/mark
    - chmod +x mark
  script:
    - ./mark --file README.md --space DOCS
  only:
    - main
  variables:
    CONFLUENCE_URL: $CONFLUENCE_URL
    CONFLUENCE_USERNAME: $CONFLUENCE_USERNAME
    CONFLUENCE_PASSWORD: $CONFLUENCE_API_TOKEN
```

### GitHub Actions Example

```yaml
name: Publish to Confluence

on:
  push:
    branches: [main]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Download mark
        run: |
          curl -LO https://github.com/kovetskiy/mark/releases/latest/download/mark
          chmod +x mark
      
      - name: Publish to Confluence
        env:
          CONFLUENCE_URL: ${{ secrets.CONFLUENCE_URL }}
          CONFLUENCE_USERNAME: ${{ secrets.CONFLUENCE_USERNAME }}
          CONFLUENCE_PASSWORD: ${{ secrets.CONFLUENCE_API_TOKEN }}
        run: ./mark --file README.md --space DOCS
```

---

## 🎓 Common Use Cases

### 1. Project Documentation

Keep docs in Git, auto-publish to Confluence on merge:

```bash
# In your project
mark --file README.md --space PROJ --parent "Project Docs"
mark --file docs/api.md --space PROJ --parent "API Documentation"
```

### 2. Knowledge Base

Maintain KB articles in markdown, publish on update:

```bash
mark --directory ./kb --space KB --parent "Knowledge Base"
```

### 3. Meeting Notes

Convert meeting notes to Confluence pages:

```bash
mark --file 2026-03-11-standup.md --space TEAM --parent "Standups"
```

### 4. Architecture Decision Records (ADRs)

```bash
mark --directory ./adrs --space ARCH --parent "ADRs" --labels "adr,architecture"
```

---

## 🐛 Troubleshooting

### Error: "Authentication failed"

**Solution:**
- Verify API token is correct (not password!)
- Check username is exact email used in Confluence
- Ensure token has correct permissions

**Test credentials:**
```bash
curl -u user@example.com:API_TOKEN https://your-domain.atlassian.net/wiki/rest/api/space
```

### Error: "Page not found"

**Solution:**
- Verify space key is correct (case-sensitive)
- Check parent page title is exact (including spaces)
- Ensure you have access to the space

### Error: "Invalid markdown"

**Solution:**
- Check for unclosed code blocks
- Verify table syntax
- Test markdown locally first:
  ```bash
  mark --file test.md --dry-run
  ```

### Images Not Uploading

**Solution:**
- Use relative paths: `./images/diagram.png`
- Or use absolute URLs: `https://example.com/image.png`
- Ensure image files exist in the specified path

---

## 💡 Tips & Tricks

### 1. Dry Run Before Publishing

```bash
mark --file doc.md --dry-run
```

### 2. Preview Converted HTML

```bash
mark --file doc.md --preview > output.html
```

### 3. Update Only if Changed

```bash
mark --file doc.md --update-only-if-modified
```

### 4. Set Default Space

Create `~/.markrc`:
```yaml
url: https://your-company.atlassian.net
username: your.email@company.com
space: DOCS
```

### 5. Batch Processing

```bash
# Publish all markdown files in folder
for file in *.md; do
  mark --file "$file" --space DOCS
done
```

---

## 📚 Additional Resources

- **Official GitHub:** https://github.com/kovetskiy/mark
- **Confluence REST API:** https://developer.atlassian.com/cloud/confluence/rest/
- **Markdown Spec:** https://commonmark.org/

---

## 🤝 Next Steps

1. ✅ Install `mark` CLI
2. ✅ Get Confluence API token
3. ✅ Configure `.env` file
4. ✅ Test with `sample.md`
5. ✅ Publish your first document
6. ✅ Set up CI/CD automation

---

**Questions?** Check `SETUP.md` for detailed setup instructions!

**Created:** 2026-03-11  
**Author:** Master Yang (via Helpful Bob)  
**License:** MIT

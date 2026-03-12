# Mark CLI - Quick Reference

**One-page cheat sheet for publishing markdown to Confluence.**

---

## 📦 Installation

```bash
# Windows
Invoke-WebRequest -Uri "https://github.com/kovetskiy/mark/releases/latest/download/mark.exe" -OutFile "mark.exe"

# Linux
curl -LO https://github.com/kovetskiy/mark/releases/latest/download/mark-linux-amd64
mv mark-linux-amd64 mark && chmod +x mark

# macOS (Intel)
curl -LO https://github.com/kovetskiy/mark/releases/latest/download/mark-darwin-amd64
mv mark-darwin-amd64 mark && chmod +x mark

# macOS (Apple Silicon)
curl -LO https://github.com/kovetskiy/mark/releases/latest/download/mark-darwin-arm64
mv mark-darwin-arm64 mark && chmod +x mark
```

---

## 🔧 Basic Commands

```bash
# Publish file
mark --file README.md --space DOCS

# Publish with parent
mark --file doc.md --space DOCS --parent "Documentation"

# Publish with custom title
mark --file doc.md --space DOCS --title "Custom Title"

# Update existing page by ID
mark --file doc.md --page-id 123456789

# Dry run (preview only)
mark --file doc.md --dry-run

# Publish directory
mark --directory ./docs --space DOCS
```

---

## 🔐 Authentication

### Option 1: Command Line
```bash
mark \
  --file doc.md \
  --url https://your-company.atlassian.net \
  --username your.email@company.com \
  --password YOUR_API_TOKEN \
  --space DOCS
```

### Option 2: Environment Variables
```bash
export CONFLUENCE_URL="https://your-company.atlassian.net"
export CONFLUENCE_USERNAME="your.email@company.com"
export CONFLUENCE_PASSWORD="YOUR_API_TOKEN"

mark --file doc.md --space DOCS
```

### Option 3: .env File
```bash
# Create .env
cat > .env <<EOF
CONFLUENCE_URL="https://your-company.atlassian.net"
CONFLUENCE_USERNAME="your.email@company.com"
CONFLUENCE_PASSWORD="YOUR_API_TOKEN"
CONFLUENCE_SPACE="DOCS"
EOF

# Then just:
mark --file doc.md
```

---

## 📝 Frontmatter

```markdown
---
title: My Document
space: DOCS
parent: Documentation
labels: [api, guide]
---

# Content starts here
```

Then publish:
```bash
mark --file doc.md  # Uses frontmatter values
```

---

## 🚀 Common Use Cases

### Publish README
```bash
mark --file README.md --space PROJ --parent "Project Docs"
```

### Update Existing Page
```bash
# By page ID
mark --file README.md --page-id 123456789

# By title (mark finds and updates)
mark --file README.md --space DOCS --title "README"
```

### Bulk Publish
```bash
# All markdown files in folder
for file in *.md; do
  mark --file "$file" --space DOCS
done

# With parent
for file in docs/*.md; do
  mark --file "$file" --space DOCS --parent "Documentation"
done
```

### Publish with Hierarchy
```bash
# Create parent page first
mark --file docs/index.md --space DOCS --title "Documentation"

# Then children
mark --file docs/setup.md --space DOCS --parent "Documentation"
mark --file docs/api.md --space DOCS --parent "Documentation"
```

---

## 🎨 Markdown Features

| Feature | Syntax | Confluence |
|---------|--------|-----------|
| **Bold** | `**text**` | ✅ |
| *Italic* | `*text*` | ✅ |
| ~~Strike~~ | `~~text~~` | ✅ |
| `Code` | \`code\` | ✅ |
| [Link](url) | `[text](url)` | ✅ |
| ![Image](url) | `![alt](url)` | ✅ |
| > Quote | `> text` | ✅ |
| `code block` | \`\`\`lang | ✅ |
| - List | `- item` | ✅ |
| 1. List | `1. item` | ✅ |
| Table | `\| col \|` | ✅ |
| --- | `---` | ✅ |
| Mermaid | \`\`\`mermaid | ⚠️ (plugin) |

---

## 🏗️ CI/CD Examples

### GitLab CI
```yaml
publish:
  script:
    - curl -LO https://github.com/kovetskiy/mark/releases/latest/download/mark
    - chmod +x mark
    - ./mark --file README.md --space DOCS
  variables:
    CONFLUENCE_URL: $CONFLUENCE_URL
    CONFLUENCE_USERNAME: $CONFLUENCE_USERNAME
    CONFLUENCE_PASSWORD: $CONFLUENCE_API_TOKEN
```

### GitHub Actions
```yaml
- name: Publish
  env:
    CONFLUENCE_URL: ${{ secrets.CONFLUENCE_URL }}
    CONFLUENCE_USERNAME: ${{ secrets.CONFLUENCE_USERNAME }}
    CONFLUENCE_PASSWORD: ${{ secrets.CONFLUENCE_API_TOKEN }}
  run: |
    curl -LO https://github.com/kovetskiy/mark/releases/latest/download/mark
    chmod +x mark
    ./mark --file README.md --space DOCS
```

---

## 🐛 Quick Fixes

### Error: "401 Unauthorized"
```bash
# Test credentials
curl -u USER:TOKEN https://your-company.atlassian.net/wiki/rest/api/space
```

### Error: "404 Space not found"
- Check space key is correct (case-sensitive!)
- Verify you have access

### Error: "403 Forbidden"
- Check edit permissions
- Verify API token scopes

### Images not uploading
- Use relative paths: `./images/pic.png`
- Or absolute URLs: `https://example.com/pic.png`

---

## 📊 Useful Flags

| Flag | Description |
|------|-------------|
| `--file <path>` | Markdown file to publish |
| `--url <url>` | Confluence URL |
| `--username <user>` | Confluence username |
| `--password <token>` | API token (not password!) |
| `--space <key>` | Confluence space key |
| `--parent <title>` | Parent page title |
| `--title <title>` | Override page title |
| `--page-id <id>` | Update specific page |
| `--dry-run` | Preview without publishing |
| `--directory <path>` | Publish entire directory |
| `--labels <list>` | Add labels (comma-separated) |
| `--minor-edit` | Mark as minor edit |
| `--debug` | Show debug output |

---

## 🔗 Links

- **GitHub:** https://github.com/kovetskiy/mark
- **Confluence API:** https://developer.atlassian.com/cloud/confluence/rest/
- **Get API Token:** https://id.atlassian.com/manage-profile/security/api-tokens

---

**Print this page for quick reference!** 📄

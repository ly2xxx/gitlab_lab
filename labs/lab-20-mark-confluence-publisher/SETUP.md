# Complete Setup Guide - Mark Confluence Publisher

**Step-by-step instructions for setting up mark CLI tool to publish markdown to Confluence.**

---

## 🎯 Prerequisites

Before starting, ensure you have:

- [ ] Confluence Cloud or Server access
- [ ] Permission to create/edit pages in target space
- [ ] Admin rights to generate API tokens
- [ ] PowerShell 5.1+ (Windows) or Bash (Linux/macOS)

---

## 📝 Step 1: Get Confluence API Token

### For Confluence Cloud (atlassian.net)

1. **Go to API Tokens page:**
   - Visit: https://id.atlassian.com/manage-profile/security/api-tokens
   - Or: Profile → Security → API tokens

2. **Create a new token:**
   - Click "Create API token"
   - Label: `mark-publisher` (or any name)
   - Click "Create"

3. **Copy the token:**
   - ⚠️ **IMPORTANT:** Copy immediately - you can't view it again!
   - Save in a secure location temporarily

### For Confluence Server (self-hosted)

1. **Generate Personal Access Token:**
   - Go to: Profile → Personal Access Tokens
   - Create new token with read/write permissions
   - Copy the token

---

## 🔧 Step 2: Install Mark CLI

### Option A: Download Binary (Recommended)

**Windows (PowerShell):**
```powershell
cd C:\code\gitlab_lab\labs\mark-confluence-publisher

# Download
Invoke-WebRequest -Uri "https://github.com/kovetskiy/mark/releases/latest/download/mark.exe" -OutFile "mark.exe"

# Verify
.\mark.exe --version
```

**Linux:**
```bash
cd ~/mark-confluence-publisher

# Download
curl -LO https://github.com/kovetskiy/mark/releases/latest/download/mark-linux-amd64
mv mark-linux-amd64 mark
chmod +x mark

# Verify
./mark --version
```

**macOS (Intel):**
```bash
cd ~/mark-confluence-publisher

# Download
curl -LO https://github.com/kovetskiy/mark/releases/latest/download/mark-darwin-amd64
mv mark-darwin-amd64 mark
chmod +x mark

# Verify
./mark --version
```

**macOS (Apple Silicon):**
```bash
cd ~/mark-confluence-publisher

# Download
curl -LO https://github.com/kovetskiy/mark/releases/latest/download/mark-darwin-arm64
mv mark-darwin-arm64 mark
chmod +x mark

# Verify
./mark --version
```

### Option B: Using Scripts

**Windows:**
```powershell
.\publish.ps1 -Install
```

**Linux/macOS:**
```bash
bash publish.sh --install
```

### Option C: Install via Go (if you have Go)

```bash
go install github.com/kovetskiy/mark@latest

# Verify
mark --version
```

---

## 🔐 Step 3: Configure Credentials

### Create .env file

1. **Copy template:**
   ```bash
   copy .env.template .env      # Windows
   cp .env.template .env        # Linux/macOS
   ```

2. **Edit .env:**
   ```bash
   notepad .env      # Windows
   nano .env         # Linux/macOS
   code .env         # VS Code
   ```

3. **Fill in your details:**
   ```env
   CONFLUENCE_URL="https://your-company.atlassian.net"
   CONFLUENCE_USERNAME="your.email@company.com"
   CONFLUENCE_PASSWORD="your_api_token_here"
   CONFLUENCE_SPACE="DOCS"
   CONFLUENCE_PARENT="Documentation"
   ```

**Example (Confluence Cloud):**
```env
CONFLUENCE_URL="https://acme.atlassian.net"
CONFLUENCE_USERNAME="john.doe@acme.com"
CONFLUENCE_PASSWORD="ATATTxxxxxxxxxxxxxxx"
CONFLUENCE_SPACE="TEAM"
CONFLUENCE_PARENT="Team Documentation"
```

**Example (Confluence Server):**
```env
CONFLUENCE_URL="https://confluence.company.com"
CONFLUENCE_USERNAME="jdoe"
CONFLUENCE_PASSWORD="your_personal_access_token"
CONFLUENCE_SPACE="ENG"
CONFLUENCE_PARENT="Engineering Docs"
```

### Verify .gitignore

Ensure `.env` is in `.gitignore`:

```bash
echo ".env" >> .gitignore
echo "*.token" >> .gitignore
echo "mark.exe" >> .gitignore
echo "mark" >> .gitignore
```

---

## 🧪 Step 4: Test Publishing

### Test 1: Publish Sample Document

**Windows:**
```powershell
.\publish.ps1 sample.md
```

**Linux/macOS:**
```bash
bash publish.sh sample.md
```

**Expected output:**
```
==================================================
📝 Mark - Confluence Publisher
==================================================

✅ Found mark at: ./mark.exe
ℹ️  Loading configuration from .env...
✅ Configuration loaded
✅ Found file: sample.md
ℹ️  Target space: DOCS
ℹ️  Publishing to Confluence...

✅ Published successfully!
```

### Test 2: Dry Run (Preview Only)

**Windows:**
```powershell
.\publish.ps1 sample.md -DryRun
```

**Linux/macOS:**
```bash
bash publish.sh sample.md --dry-run
```

This shows what would happen without actually publishing.

### Test 3: Specific Space and Parent

**Windows:**
```powershell
.\publish.ps1 sample.md -Space "PROJ" -Parent "Project Docs"
```

**Linux/macOS:**
```bash
bash publish.sh sample.md --space "PROJ" --parent "Project Docs"
```

---

## 🔍 Step 5: Verify in Confluence

1. **Open Confluence:**
   - Go to your Confluence URL
   - Navigate to the target space (e.g., DOCS)

2. **Find the page:**
   - Check under parent page if specified
   - Or search for "Sample Document - Mark Publisher Test"

3. **Verify content:**
   - Check formatting (headers, tables, code blocks)
   - Verify images loaded correctly
   - Test links work

---

## 🚀 Step 6: Publish Your Own Documents

### Method 1: Using Scripts

**Windows:**
```powershell
# Publish README
.\publish.ps1 README.md

# With custom title
.\publish.ps1 docs\api.md -Title "API Documentation"

# To different space
.\publish.ps1 meeting-notes.md -Space "TEAM" -Parent "Meetings"
```

**Linux/macOS:**
```bash
# Publish README
bash publish.sh README.md

# With custom title
bash publish.sh docs/api.md --title "API Documentation"

# To different space
bash publish.sh meeting-notes.md --space "TEAM" --parent "Meetings"
```

### Method 2: Direct mark Command

```bash
mark \
  --file your-document.md \
  --url https://your-company.atlassian.net \
  --space DOCS \
  --parent "Documentation" \
  --username your.email@company.com \
  --password YOUR_API_TOKEN
```

### Method 3: With Environment Variables

```bash
# Set once (or use .env)
export CONFLUENCE_URL="https://your-company.atlassian.net"
export CONFLUENCE_USERNAME="your.email@company.com"
export CONFLUENCE_PASSWORD="your_api_token"

# Then just:
mark --file your-document.md --space DOCS
```

---

## 📊 Step 7: Bulk Publishing

### Publish Entire Folder

```bash
# Windows (PowerShell)
Get-ChildItem *.md | ForEach-Object {
  .\publish.ps1 $_.Name
}

# Linux/macOS
for file in *.md; do
  bash publish.sh "$file"
done
```

### Publish with Hierarchy

**Folder structure:**
```
docs/
├── index.md          → Root page
├── api/
│   ├── index.md      → API Documentation (parent)
│   ├── auth.md       → Child page
│   └── endpoints.md  → Child page
└── guides/
    └── setup.md
```

**Script:**
```bash
# Publish root
mark --file docs/index.md --space DOCS

# Publish API section
mark --file docs/api/index.md --space DOCS --parent "Documentation"
mark --file docs/api/auth.md --space DOCS --parent "API Documentation"
mark --file docs/api/endpoints.md --space DOCS --parent "API Documentation"

# Publish guides
mark --file docs/guides/setup.md --space DOCS --parent "Documentation"
```

---

## 🎯 Step 8: Add Frontmatter (Optional)

Instead of passing arguments, embed metadata in markdown:

```markdown
---
title: My Document Title
space: DOCS
parent: Documentation
labels: [api, guide, important]
---

# Content starts here
```

Then just publish:
```bash
mark --file document.md
```

mark will use the frontmatter values automatically.

---

## ⚙️ Step 9: Advanced Configuration

### Create ~/.markrc (Global Config)

**Linux/macOS:**
```bash
cat > ~/.markrc <<EOF
url: https://your-company.atlassian.net
username: your.email@company.com
space: DOCS
parent: Documentation
EOF
```

**Windows:**
```powershell
@"
url: https://your-company.atlassian.net
username: your.email@company.com
space: DOCS
parent: Documentation
"@ | Out-File -FilePath "$env:USERPROFILE\.markrc" -Encoding UTF8
```

Then set password via environment:
```bash
export CONFLUENCE_PASSWORD="your_api_token"
```

Now you can publish with minimal arguments:
```bash
mark --file document.md
```

---

## 🐛 Troubleshooting

### Error: "mark: command not found"

**Solution:**
- Ensure mark is in current directory or PATH
- Try: `.\mark.exe` (Windows) or `./mark` (Linux/macOS)
- Or reinstall using scripts with `--install` flag

### Error: "401 Unauthorized"

**Possible causes:**
1. Invalid API token
2. Wrong username
3. Token expired

**Solution:**
```bash
# Test credentials
curl -u your.email@company.com:YOUR_API_TOKEN \
  https://your-company.atlassian.net/wiki/rest/api/space

# If that works, check mark credentials match
```

### Error: "404 Not Found - Space not found"

**Solution:**
- Verify space key is correct (case-sensitive!)
- Check you have access to the space
- Try: View space in browser → URL contains space key

### Error: "403 Forbidden"

**Solution:**
- Verify you have edit permissions in the space
- Check page restrictions
- Ensure API token has correct scopes

### Images Not Uploading

**Solution:**
- Use relative paths: `./images/diagram.png`
- Or absolute URLs: `https://example.com/image.png`
- Ensure image files exist
- Check file size limits (Confluence may have limits)

---

## ✅ Next Steps

1. ✅ Publish sample.md to verify setup
2. ✅ Create your own markdown document
3. ✅ Test publishing to different spaces
4. ✅ Set up CI/CD automation (optional)
5. ✅ Share with your team

---

## 📚 Additional Resources

- **Mark GitHub:** https://github.com/kovetskiy/mark
- **Confluence API:** https://developer.atlassian.com/cloud/confluence/rest/
- **API Token Guide:** https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/

---

**Setup complete! 🎉**

Return to [README.md](README.md) for usage examples.

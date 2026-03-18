#!/usr/bin/env python3
"""
gitlab_delta_md.py
──────────────────
Generate a structured Markdown code-delta report between two GitLab release tags.
Outputs a .md file ready for Claude / AI summarisation or Confluence upload.

Usage:
    python gitlab_delta_md.py \
        --url https://gitlab.com \
        --project-id 12345 \
        --token glpat-xxxx \
        --from-tag v1.0.0 \
        --to-tag v1.1.0 \
        [--output delta_v1.0.0_v1.1.0.md]

Alternatively set env vars:
    GITLAB_URL, GITLAB_TOKEN, GITLAB_PROJECT_ID
"""

import argparse
import os
import sys
import json
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime, timezone


# ─── GitLab API helpers ───────────────────────────────────────────────────────

def api_get(base_url: str, token: str, path: str, params: dict = None) -> any:
    """Make a paginated-aware GET request to the GitLab API."""
    params = params or {}
    params.setdefault("per_page", 100)
    query = urllib.parse.urlencode(params)
    url = f"{base_url}/api/v4/{path}?{query}"
    req = urllib.request.Request(url, headers={"PRIVATE-TOKEN": token})
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        print(f"[ERROR] GitLab API {e.code}: {e.reason} → {url}", file=sys.stderr)
        sys.exit(1)


def get_compare(base_url, token, project_id, from_tag, to_tag):
    """Call /repository/compare to get commits + diffs between two refs."""
    path = f"projects/{urllib.parse.quote(str(project_id), safe='')}/repository/compare"
    return api_get(base_url, token, path, {
        "from": from_tag,
        "to": to_tag,
        "straight": "true"
    })


def get_tag_info(base_url, token, project_id, tag_name):
    """Fetch tag metadata."""
    tag_enc = urllib.parse.quote(tag_name, safe="")
    path = f"projects/{urllib.parse.quote(str(project_id), safe='')}/repository/tags/{tag_enc}"
    return api_get(base_url, token, path)


def get_project_info(base_url, token, project_id):
    """Fetch project metadata."""
    path = f"projects/{urllib.parse.quote(str(project_id), safe='')}"
    return api_get(base_url, token, path)


# ─── Markdown builders ────────────────────────────────────────────────────────

def format_commit_table(commits: list) -> str:
    if not commits:
        return "_No commits found in this range._\n"
    rows = ["| SHA | Author | Date | Message |",
            "|-----|--------|------|---------|"]
    for c in commits:
        sha   = c.get("short_id", c["id"][:8])
        author = c.get("author_name", "unknown").replace("|", "\\|")
        date   = c.get("committed_date", "")[:10]
        msg    = c.get("title", "").replace("|", "\\|")[:80]
        rows.append(f"| `{sha}` | {author} | {date} | {msg} |")
    return "\n".join(rows) + "\n"


def classify_diff(diff: dict) -> str:
    if diff.get("new_file"):   return "➕ Added"
    if diff.get("deleted_file"): return "🗑️ Deleted"
    if diff.get("renamed_file"): return "🔄 Renamed"
    return "✏️ Modified"


def summarise_diffs(diffs: list) -> tuple[str, dict]:
    """Return a file-change summary table + category breakdown."""
    if not diffs:
        return "_No file changes detected._\n", {}

    categories = {"➕ Added": [], "🗑️ Deleted": [], "🔄 Renamed": [], "✏️ Modified": []}
    rows = ["| Status | File | +Lines | -Lines |",
            "|--------|------|--------|--------|"]

    for d in diffs:
        status = classify_diff(d)
        path   = d.get("new_path") or d.get("old_path", "unknown")
        diff_text = d.get("diff", "")
        added   = diff_text.count("\n+") 
        removed = diff_text.count("\n-")
        categories[status].append(path)
        rows.append(f"| {status} | `{path}` | +{added} | -{removed} |")

    return "\n".join(rows) + "\n", categories


def category_summary(categories: dict) -> str:
    lines = []
    for label, files in categories.items():
        if files:
            lines.append(f"- **{label}**: {len(files)} file(s)")
    return "\n".join(lines) if lines else "_No changes._"


def group_commits_by_type(commits: list) -> dict:
    """Group commits by conventional-commit prefix (feat, fix, chore, etc.)."""
    groups = {
        "feat":     [],
        "fix":      [],
        "refactor": [],
        "chore":    [],
        "docs":     [],
        "test":     [],
        "ci":       [],
        "perf":     [],
        "other":    [],
    }
    for c in commits:
        title = c.get("title", "")
        matched = False
        for key in groups:
            if key != "other" and title.lower().startswith(f"{key}"):
                groups[key].append(c)
                matched = True
                break
        if not matched:
            groups["other"].append(c)
    return groups


def format_grouped_commits(groups: dict) -> str:
    label_map = {
        "feat":     "🚀 Features",
        "fix":      "🐛 Bug Fixes",
        "refactor": "♻️ Refactoring",
        "perf":     "⚡ Performance",
        "docs":     "📖 Documentation",
        "test":     "🧪 Tests",
        "ci":       "⚙️ CI/CD",
        "chore":    "🔧 Chores",
        "other":    "📌 Other",
    }
    out = []
    for key, label in label_map.items():
        items = groups.get(key, [])
        if items:
            out.append(f"\n### {label}\n")
            for c in items:
                sha  = c.get("short_id", c["id"][:8])
                msg  = c.get("title", "")
                auth = c.get("author_name", "")
                out.append(f"- `{sha}` {msg} _(by {auth})_")
    return "\n".join(out) if out else "_No commits to display._"


# ─── Main report builder ──────────────────────────────────────────────────────

def build_report(project, from_tag_info, to_tag_info, compare_data,
                 from_tag: str, to_tag: str) -> str:

    project_name = project.get("name_with_namespace", str(project.get("id")))
    project_url  = project.get("web_url", "")

    from_date = (from_tag_info.get("commit") or {}).get("committed_date", "")[:10]
    to_date   = (to_tag_info.get("commit")   or {}).get("committed_date", "")[:10]

    commits = compare_data.get("commits", [])
    diffs   = compare_data.get("diffs", [])

    diff_table, categories = summarise_diffs(diffs)
    cat_summary = category_summary(categories)
    groups = group_commits_by_type(commits)

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    report = f"""# Code Delta Report: `{from_tag}` → `{to_tag}`

> **Project**: [{project_name}]({project_url})  
> **Base tag**: `{from_tag}` ({from_date})  
> **Target tag**: `{to_tag}` ({to_date})  
> **Generated**: {generated_at}  
> **Total commits**: {len(commits)}  
> **Files changed**: {len(diffs)}

---

## Executive Summary

| Metric | Count |
|--------|-------|
| Commits | {len(commits)} |
| Files changed | {len(diffs)} |
| Added | {len(categories.get("➕ Added", []))} |
| Modified | {len(categories.get("✏️ Modified", []))} |
| Deleted | {len(categories.get("🗑️ Deleted", []))} |
| Renamed | {len(categories.get("🔄 Renamed", []))} |

**Change breakdown:**
{cat_summary}

---

## Commits by Type

{format_grouped_commits(groups)}

---

## All Commits (chronological)

{format_commit_table(commits)}

---

## File Changes

{diff_table}

---

## Notes for AI Summarisation

> This report was auto-generated from the GitLab Compare API.  
> Feed this document to Claude with a prompt such as:  
> *"Summarise the above code delta for a release note / Confluence page.  
>  Highlight breaking changes, new features, and risk areas."*

---
_Generated by `gitlab_delta_md.py`_
"""
    return report


# ─── CLI ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Generate a Markdown code-delta report between two GitLab tags."
    )
    parser.add_argument("--url",        default=os.getenv("GITLAB_URL", "https://gitlab.com"),
                        help="GitLab base URL (default: https://gitlab.com or $GITLAB_URL)")
    parser.add_argument("--token",      default=os.getenv("GITLAB_TOKEN"),
                        help="GitLab personal access token ($GITLAB_TOKEN)")
    parser.add_argument("--project-id", default=os.getenv("GITLAB_PROJECT_ID"),
                        help="GitLab project ID or URL-encoded path ($GITLAB_PROJECT_ID)")
    parser.add_argument("--from-tag",   required=True, help="Base tag (older)")
    parser.add_argument("--to-tag",     required=True, help="Target tag (newer)")
    parser.add_argument("--output",     default=None,
                        help="Output .md filename (default: delta_<from>_<to>.md)")

    args = parser.parse_args()

    if not args.token:
        print("[ERROR] --token or $GITLAB_TOKEN is required.", file=sys.stderr)
        sys.exit(1)
    if not args.project_id:
        print("[ERROR] --project-id or $GITLAB_PROJECT_ID is required.", file=sys.stderr)
        sys.exit(1)

    base_url   = args.url.rstrip("/")
    token      = args.token
    project_id = args.project_id
    from_tag   = args.from_tag
    to_tag     = args.to_tag
    out_file   = args.output or f"delta_{from_tag}_{to_tag}.md".replace("/", "_")

    print(f"[*] Fetching project info …")
    project = get_project_info(base_url, token, project_id)

    print(f"[*] Fetching tag info for {from_tag} …")
    from_tag_info = get_tag_info(base_url, token, project_id, from_tag)

    print(f"[*] Fetching tag info for {to_tag} …")
    to_tag_info = get_tag_info(base_url, token, project_id, to_tag)

    print(f"[*] Fetching compare data ({from_tag} → {to_tag}) …")
    compare_data = get_compare(base_url, token, project_id, from_tag, to_tag)

    commits = compare_data.get("commits", [])
    diffs   = compare_data.get("diffs",   [])
    print(f"[*] Found {len(commits)} commits, {len(diffs)} changed files.")

    print(f"[*] Building report …")
    report = build_report(project, from_tag_info, to_tag_info,
                          compare_data, from_tag, to_tag)

    with open(out_file, "w", encoding="utf-8") as f:
        f.write(report)

    print(f"[✓] Report written to: {out_file}")


if __name__ == "__main__":
    main()

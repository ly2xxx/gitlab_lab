# GitLab Delta Markdown Generator

This script generates a comprehensive Markdown report of differences (commits, file changes) between two GitLab references (tags, branches, or commit SHAs). It is designed to format repository changes perfectly for AI tools like Claude to generate release notes.

## How to use it

### Basic run

You can run the script by passing your GitLab connection details and the two references you want to compare:

```bash
python gitlab_delta_md.py \
  --url https://gitlab.com \
  --token glpat-xxxx \
  --project-id 1234 \
  --from-ref v1.0.0 \
  --to-ref v1.1.0
```

*(Note: The `--from-ref` and `--to-ref` arguments seamlessly accept tags, branch names, or commit SHAs.)*

### Via Environment Variables (Better for CI)

Alternatively, provide the connection details via environment variables to keep your commands clean:

```bash
export GITLAB_URL=https://gitlab.com
export GITLAB_TOKEN=glpat-xxxx
export GITLAB_PROJECT_ID=1234

python gitlab_delta_md.py --from-ref v1.0.0 --to-ref v1.1.0
# → writes delta_v1.0.0_v1.1.0.md
```

### Comparing Branches and Tags

The GitLab Compare API accepts any ref, so you can mix and match seamlessly:

```bash
# Between two release branches
python gitlab_delta_md.py \
  --from-ref release/1.0 \
  --to-ref release/1.1

# Between main and a release branch
python gitlab_delta_md.py \
  --from-ref main \
  --to-ref release/1.1

# Mix of tag and branch
python gitlab_delta_md.py \
  --from-ref v1.0.0 \
  --to-ref release/1.1
```

## What the output `.md` contains

The generated Markdown file includes several structured sections to give a complete view of the delta:

- **Executive Summary**: Counts of commits and files added/modified/deleted.
- **Commits by Type**: Auto-grouped by conventional commit prefix (`feat`/`fix`/`chore` etc.).
- **All Commits Table**: SHA, author, date, and commit message.
- **File Changes Table**: Per-file status + line delta counts.
- **AI Prompt Note**: Ready-made prompt for feeding the report directly to Claude.

## Next Step — Pipe into Claude

Once you have the `.md` delta file, you can feed it to your existing release pipeline (or PoC) or just paste it directly into Claude along with this prompt:

> *"Summarise this code delta for a Confluence release note. Highlight breaking changes, new features, and risk areas."*

**(Future enhancement idea: Add a `--claude-summarise` flag that auto-calls the Anthropic API and appends an AI summary section directly to the same `.md` file!)**

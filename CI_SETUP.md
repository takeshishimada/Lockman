# CI/CD Setup Guide

This guide explains how to configure your environment for the CI/CD workflows.

## Prerequisites

### 1. GitHub Pages Setup (for documentation.yml)

Enable GitHub Pages for automatic documentation deployment:

1. Go to **Settings** → **Pages** in your GitHub repository
2. Under **Source**, select **Deploy from a branch**
3. Select **gh-pages** branch and **/ (root)** folder
4. Click **Save**

**Note**: The gh-pages branch will be created automatically by the documentation workflow on first run.

### 2. Repository Permissions

Ensure GitHub Actions has write permissions:

1. Go to **Settings** → **Actions** → **General**
2. Under **Workflow permissions**, select **Read and write permissions**
3. Check **Allow GitHub Actions to create and approve pull requests**
4. Click **Save**

### 3. Branch Protection Rules (Optional but Recommended)

Protect main and develop branches:

1. Go to **Settings** → **Branches**
2. Add rule for `main` and `develop`:
   - ✅ Require a pull request before merging
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging
   - ✅ Include administrators (optional)

### 4. Secrets Configuration (Optional)

For Slack notifications in release.yml:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Add new repository secret: `SLACK_WEBHOOK_URL`
3. Uncomment the Slack notification section in `.github/workflows/release.yml`

## Workflow Triggers

### documentation.yml
- **Automatic**: On release publish and main branch push
- **Manual**: Go to **Actions** → **Documentation** → **Run workflow**

### release.yml
- **Automatic**: On release publish
- **Manual**: Go to **Actions** → **Release** → **Run workflow**

### format.yml
- **Automatic**: On push to main or develop branches
- **Manual**: Go to **Actions** → **Format** → **Run workflow**

## Troubleshooting

### Documentation not appearing
- Check if GitHub Pages is enabled
- Verify the gh-pages branch exists
- Check workflow run logs for errors
- Documentation URL: `https://[username].github.io/Lockman/`

### Format workflow creating too many commits
- The `[skip ci]` in commit messages should prevent loops
- If issues persist, consider limiting to specific paths

### Release workflow failing
- Ensure release tags follow semantic versioning (e.g., 1.0.0)
- Check that Xcode 16.0 is available on the runner

## Local Testing

To test swift-format locally:
```bash
# Install swift-format
brew install swift-format

# Run formatting
make format

# Check without modifying files
swift-format lint --recursive Sources Tests Examples
```

## Viewing Documentation Locally

To generate and view documentation locally:
```bash
# Generate documentation
swift package generate-documentation --target Lockman

# Open in browser (macOS)
open .build/plugins/Swift-DocC/outputs/Lockman/Lockman.doccarchive
```
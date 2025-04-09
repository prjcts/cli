#!/usr/bin/env bash

set -euo pipefail

VERSION="${1:-}"

# Validate semver
if [[ -z "$VERSION" || ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Please provide a valid semver version, e.g. 0.2.0"
  exit 1
fi

# Constants
TAG="v$VERSION"
REPO_URL="https://github.com/prjcts/cli"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/version"
INSTALL_SCRIPT="$ROOT_DIR/install.sh"
CHANGELOG="$ROOT_DIR/CHANGELOG.md"

cd "$ROOT_DIR"

# Ensure clean git state
if [[ -n "$(git status --porcelain)" ]]; then
  echo "❌ Git working directory is not clean. Commit or stash your changes first."
  exit 1
fi

# Write version file
echo "$VERSION" > "$VERSION_FILE"

# Replace {{VERSION}} in install.sh
sed -i.bak "s/{{VERSION}}/$TAG/g" "$INSTALL_SCRIPT"
rm -f "$INSTALL_SCRIPT.bak"

# Get last tag if exists
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
COMMITS=$(git log "$LAST_TAG"..HEAD --pretty=format:"- %s")

# Ensure CHANGELOG.md exists
touch "$CHANGELOG"

# Prepend changelog entry
{
  echo "## $TAG - $(date +%Y-%m-%d)"
  echo
  echo "$COMMITS"
  echo
  echo
  cat "$CHANGELOG"
} > "$CHANGELOG.tmp" && mv "$CHANGELOG.tmp" "$CHANGELOG"

echo "✅ Updated version file, install script, and changelog."

# Commit and tag
git add version install.sh CHANGELOG.md
git commit -m "Release $TAG"
git tag "$TAG"

# Push changes and tag
git push origin main
git push origin "$TAG"

# Show release URL
echo ""
echo "🚀 Published tag: $TAG"
echo "🔗 GitHub release: $REPO_URL/releases/tag/$TAG"

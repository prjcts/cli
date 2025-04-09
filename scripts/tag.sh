#!/usr/bin/env bash

set -euo pipefail

# Constants
REPO_URL="https://github.com/prjcts/cli"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/version"
INSTALL_SCRIPT="$ROOT_DIR/install.sh"
CHANGELOG="$ROOT_DIR/CHANGELOG.md"
README="$ROOT_DIR/README.md"

cd "$ROOT_DIR"

# Read current version
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "❌ version file not found"
  exit 1
fi

CURRENT_VERSION=$(<"$VERSION_FILE")
VERSION_INPUT="${1:-patch}"

# Function to increment versions
increment_version() {
  local type="$1"
  IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
  case "$type" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "$major.$((minor + 1)).0" ;;
    patch) echo "$major.$minor.$((patch + 1))" ;;
    *) echo "$type" ;;  # assume full version was passed (e.g. 0.3.2)
  esac
}

# Determine new version
NEW_VERSION=$(increment_version "$VERSION_INPUT")

# Validate semver
if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Invalid version: $NEW_VERSION"
  exit 1
fi

TAG="v$NEW_VERSION"

# Ensure clean git state
if [[ -n "$(git status --porcelain)" ]]; then
  echo "❌ Git working directory is not clean. Commit or stash your changes first."
  exit 1
fi

# Update version file
echo "$NEW_VERSION" > "$VERSION_FILE"

# Replace {{VERSION}} in install.sh and README.md
sed -i.bak "s/{{VERSION}}/$TAG/g" "$INSTALL_SCRIPT"
rm -f "$INSTALL_SCRIPT.bak"

if [[ -f "$README" ]]; then
  sed -i.bak -E "s|(https://raw.githubusercontent.com/prjcts/cli/)(v[0-9]+\.[0-9]+\.[0-9]+|\{\{VERSION\}\})|\1$TAG|g" "$README"
  rm -f "$README.bak"
  echo "✅ Updated install command in README.md to use $TAG"
fi

# Create or prepend changelog entry
touch "$CHANGELOG"
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
COMMITS=$(git log "$LAST_TAG"..HEAD --pretty=format:"- %s")

{
  echo "## $TAG - $(date +%Y-%m-%d)"
  echo
  echo "$COMMITS"
  echo
  echo
  cat "$CHANGELOG"
} > "$CHANGELOG.tmp" && mv "$CHANGELOG.tmp" "$CHANGELOG"

echo "✅ Updated version, install.sh, README.md, and changelog."

# Commit, tag, and push
git add version install.sh README.md CHANGELOG.md
git commit -m "Release $TAG"
git tag "$TAG"
git push origin main
git push origin "$TAG"

# Output link
echo ""
echo "🚀 Published tag: $TAG"
echo "🔗 GitHub release: $REPO_URL/releases/tag/$TAG"

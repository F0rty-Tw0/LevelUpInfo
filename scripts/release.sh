#!/usr/bin/env bash
#
# Usage: bash scripts/release.sh <version>
# Example: bash scripts/release.sh 1.0.0
##
## Accepts 1.0.0 or v1.0.0 and always normalizes to v-prefixed
## tags and file versions.
##
## Write player notes under '## [Unreleased]' in CHANGELOG.md as you go.
## This script moves them into a dated '## [x.y.z]' section (archiving the
## finished series when a new minor/major opens), bumps the TOC and
## Constants.lua versions, commits, and tags. It refuses to run when
## [Unreleased] is empty, unless the top section already is this version.

set -euo pipefail

INPUT_VERSION="${1:-}"

if [[ -z "$INPUT_VERSION" ]]; then
  echo "Usage: bash scripts/release.sh <version>"
  echo "Example: bash scripts/release.sh 1.0.0"
  exit 1
fi

if ! [[ "$INPUT_VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version must be semver (e.g. 1.0.0 or v1.0.0)"
  exit 1
fi

NORMALIZED_VERSION="${INPUT_VERSION#v}"
TAG_VERSION="v${NORMALIZED_VERSION}"

# Ensure working tree is clean
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

# Ensure tag doesn't already exist
if git show-ref --verify --quiet "refs/tags/${TAG_VERSION}"; then
  echo "Error: Tag '${TAG_VERSION}' already exists."
  exit 1
fi

echo "Releasing LevelUpInfo ${TAG_VERSION}..."

# The TOC lists one interface number per client, in a fixed slot order:
# Classic Era, WoW: Forever, TBC Anniversary. Check the shape before any edit.
CURRENT_INTERFACE=$(sed -n 's/^## Interface: //p' LevelUpInfo.toc | tr -d '\r')
IFS=', ' read -r -a SLOTS <<< "$CURRENT_INTERFACE"
if [[ ${#SLOTS[@]} -ne 3 ]]; then
  echo "Error: '## Interface: ${CURRENT_INTERFACE}' must list exactly three numbers (Era, Forever, TBC)."
  exit 1
fi

# Fetch a live TOC interface number from Blizzard's patch CDN.
fetch_toc() {
  local product="$1"
  python -c "
import re, sys, urllib.request
try:
    with urllib.request.urlopen('https://us.version.battle.net/v2/products/${product}/versions', timeout=15) as r:
        text = r.read().decode('utf-8', errors='replace')
except Exception as e:
    sys.stderr.write('fetch failed for ${product}: ' + str(e) + '\n')
    sys.exit(1)
for line in text.splitlines():
    if line.startswith('us|'):
        m = re.search(r'\b(\d+)\.(\d+)\.(\d+)\.\d+\b', line)
        if m:
            a, b, c = m.groups()
            print(f'{int(a)}{int(b):02d}{int(c):02d}')
            break
"
}

echo "Fetching live TOC interface numbers from Blizzard CDN..."
# Soft-fail per client: a failed fetch keeps that slot's current value.
# WoW: Forever's beta lives under 'wow_classic_beta'; the launch product key
# is unknown until 2026-11-04.
PRODUCTS=(wow_classic_era wow_classic_beta wow_anniversary)
LABELS=(era forever tbc)
for i in 0 1 2; do
  fetched=$(fetch_toc "${PRODUCTS[$i]}") || true
  if [[ -n "$fetched" ]]; then
    SLOTS[$i]="$fetched"
    echo "  ${LABELS[$i]}: ${fetched}"
  else
    echo "  ${LABELS[$i]}: skipped (CDN fetch failed, keeping ${SLOTS[$i]})"
  fi
done
NEW_INTERFACE="${SLOTS[0]}, ${SLOTS[1]}, ${SLOTS[2]}"

# Move [Unreleased] notes into this release's section. Runs before any other
# file edit so a missing-notes error leaves the tree untouched.
python scripts/promote_changelog.py --version "${TAG_VERSION}"

sed -i "s/^## Interface: .*/## Interface: ${NEW_INTERFACE}/" LevelUpInfo.toc

# Update version in TOC
sed -i "s/^## Version: .*/## Version: ${TAG_VERSION}/" LevelUpInfo.toc

# Update version in Constants.lua
sed -i "s/VERSION = \"[^\"]*\"/VERSION = \"${TAG_VERSION}\"/" Core/Constants.lua

# Commit version + interface bump
git add LevelUpInfo.toc Core/Constants.lua CHANGELOG.md
if [[ -d archive/changelog ]]; then
  git add archive/changelog
fi
if git diff --cached --quiet; then
  echo "No TOC or version changes to commit (already up to date)."
else
  git commit -m "release: ${TAG_VERSION}"
fi

# Create annotated tag
git tag -a "${TAG_VERSION}" -m "Release ${TAG_VERSION}"

echo ""
echo "Version bumped and tag created."
echo ""
echo "To publish, push the tag:"
echo "  git push origin master ${TAG_VERSION}"
echo ""
echo "This will trigger the CI pipeline which:"
echo "  1. Runs lint checks"
echo "  2. Packages the addon"
echo "  3. Uploads to CurseForge"
echo "  4. Creates a GitHub Release"

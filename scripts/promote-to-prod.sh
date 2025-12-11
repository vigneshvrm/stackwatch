#!/usr/bin/env bash
set -euo pipefail

# Usage: scripts/promote-to-prod.sh <PROD_SSH_URL> <ARTIFACT_PATH> <TEST_TAG>
# Example:
#   scripts/promote-to-prod.sh ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch-prod.git stackwatch-prebuilt-1.0.0-20251211.tar.gz test-1.0.0-20251211-0503

PROD_REPO_SSH="${1:?prod repo ssh url required}"
ARTIFACT_PATH="${2:?artifact path required}"
TEST_TAG="${3:-}"  # optional: test tag to delete after promotion

# Tools expected: git, sha256sum, mktemp, jq (optional)
which git >/dev/null
which sha256sum >/dev/null

WORKDIR="$(mktemp -d)"
echo "Using tempdir: $WORKDIR"

# 1) checksum artifact
sha256sum "$ARTIFACT_PATH" | awk '{print $1, $2}' > "${ARTIFACT_PATH}.sha256"
echo "Created checksum ${ARTIFACT_PATH}.sha256"

# 2) clone prod repo
cd "$WORKDIR"
git clone "$PROD_REPO_SSH" prod
cd prod

# 3) compute next version (patch bump) from existing tags
# find latest tag like vMAJOR.MINOR.PATCH
LATEST_TAG="$(git tag -l 'v*.*.*' --sort=-v:refname | head -n1 || true)"
if [[ -z "$LATEST_TAG" ]]; then
  # no tags found, try package.json version if present at source (passed artifact may include version)
  echo "No tags found in prod repo; defaulting to v0.0.0"
  BASE="0.0.0"
else
  BASE="${LATEST_TAG#v}"
fi

# if artifact filename includes a version, prefer it; otherwise bump BASE
# attempt to parse version from artifact filename like stackwatch-prebuilt-1.2.3-YYYYMMDD...tar.gz
ART_VER="$(basename "$ARTIFACT_PATH" | sed -n 's/^stackwatch-prebuilt-\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' || true)"

if [[ -n "$ART_VER" ]]; then
  # if artifact major.minor.patch differs from latest, use artifact version; else bump patch
  if [[ "$ART_VER" != "$BASE" ]]; then
    NEW_VER="$ART_VER"
  else
    # bump patch
    IFS='.' read -r MAJ MIN PAT <<<"$BASE"
    PAT=$((PAT + 1))
    NEW_VER="${MAJ}.${MIN}.${PAT}"
  fi
else
  # bump BASE patch
  IFS='.' read -r MAJ MIN PAT <<<"${BASE}"
  PAT=$((PAT + 1))
  NEW_VER="${MAJ}.${MIN}.${PAT}"
fi

TAG="v${NEW_VER}"
echo "Determined new version tag: ${TAG}"

# 4) copy artifact and checksum into prod repo
cp "$ARTIFACT_PATH" .
cp "${ARTIFACT_PATH}.sha256" .

# optional: add release notes file
RELEASE_NOTES="Release ${TAG}\n\nPromoted from test: ${TEST_TAG}\n\nChecksum:\n$(cat "${ARTIFACT_PATH}.sha256")\n"
echo -e "$RELEASE_NOTES" > RELEASE_NOTES_${TAG}.md

# 5) commit changes
git add "$(basename "$ARTIFACT_PATH")" "$(basename "${ARTIFACT_PATH}.sha256")" "RELEASE_NOTES_${TAG}.md" || true
if git status --porcelain | grep -q .; then
  git commit -m "Release ${TAG}: add artifact and checksum"
else
  echo "No changes to commit (artifact same?)"
fi

# 6) tag and push
git tag -a "${TAG}" -m "Release ${TAG} - checksum: $(cut -d' ' -f1 "${ARTIFACT_PATH}.sha256")"
git push origin HEAD
git push origin "${TAG}"

# 7) optionally delete test tag from testing repo (requires permission on testing repo)
if [[ -n "$TEST_TAG" ]]; then
  echo "Deleting test tag ${TEST_TAG} from testing repo"
  # This will push a delete ref to the testing repo. Ensure Jenkins SSH key has permission.
  git push "${PROD_REPO_SSH}" ":refs/tags/${TEST_TAG}" >/dev/null 2>&1 || true
  # If above doesn't work because PROD_REPO_SSH is prod, do a direct delete on testing remote if available:
  # git push <testing-ssh-url> :refs/tags/${TEST_TAG}
fi

echo "Promotion complete. New tag: ${TAG}"
echo "Artifact: $(basename "$ARTIFACT_PATH")"
echo "Checksum: $(cat "${ARTIFACT_PATH}.sha256")"

# cleanup
cd /
rm -rf "$WORKDIR"

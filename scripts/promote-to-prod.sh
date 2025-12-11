#!/usr/bin/env bash
set -euo pipefail

# promote-to-prod.sh
# Usage: scripts/promote-to-prod.sh <PROD_SSH_URL> <ARTIFACT_PATH> <TEST_TAG>
# Example:
#   ./scripts/promote-to-prod.sh ssh://git@gitlab.../stackwatch-prod.git /var/lib/jenkins/workspace/.../latest.tar.gz test-<...>

PROD_REPO_SSH="${1:?prod repo ssh url required}"
ARTIFACT_PATH="${2:?artifact path required}"
TEST_TAG="${3:-}"  # optional: test tag to delete after promotion

# Tools required: git, sha256sum, mktemp
for cmd in git sha256sum mktemp; do
  command -v $cmd >/dev/null 2>&1 || { echo "Required command '$cmd' not found"; exit 1; }
done

# Resolve artifact path: accept absolute or relative. Try to find the file.
# If PATH is relative, try $PWD/$ARTIFACT_PATH and $WORKSPACE/$ARTIFACT_PATH (if WORKSPACE env provided).
if [[ ! -f "$ARTIFACT_PATH" ]]; then
  if [[ -n "${WORKSPACE:-}" && -f "${WORKSPACE}/${ARTIFACT_PATH}" ]]; then
    ARTIFACT_PATH="${WORKSPACE}/${ARTIFACT_PATH}"
  elif [[ -f "${PWD}/${ARTIFACT_PATH}" ]]; then
    ARTIFACT_PATH="${PWD}/${ARTIFACT_PATH}"
  else
    echo "[ERROR] Artifact not found: tried: '$ARTIFACT_PATH' '${WORKSPACE:-}/$ARTIFACT_PATH' '${PWD}/$ARTIFACT_PATH'"
    exit 1
  fi
fi

ART_BASENAME="$(basename "$ARTIFACT_PATH")"
CHECKSUM_FILE="${ARTIFACT_PATH}.sha256"
WORKDIR="$(mktemp -d)"
echo "Using tempdir: $WORKDIR"

# 1) compute checksum (create next to artifact if not already)
if [[ ! -f "$CHECKSUM_FILE" ]]; then
  sha256sum "$ARTIFACT_PATH" | awk '{print $1 "  " $2}' > "${WORKDIR}/${ART_BASENAME}.sha256"
else
  # copy existing checksum to workdir
  cp "$CHECKSUM_FILE" "${WORKDIR}/${ART_BASENAME}.sha256"
fi
echo "Created checksum ${WORKDIR}/${ART_BASENAME}.sha256"

# 2) copy artifact into tempdir so subsequent cd doesn't break paths
cp "$ARTIFACT_PATH" "${WORKDIR}/${ART_BASENAME}"

# 3) clone prod repo into tempdir and switch into it
cd "$WORKDIR"
git clone "$PROD_REPO_SSH" prod
cd prod

# 4) determine next version tag from prod repo
LATEST_TAG="$(git tag -l 'v*.*.*' --sort=-v:refname | head -n1 || true)"
if [[ -z "$LATEST_TAG" ]]; then
  BASE="0.0.0"
else
  BASE="${LATEST_TAG#v}"
fi

# Try to detect version from artifact name: stackwatch-prebuilt-1.2.3-...
ART_VER="$(echo "$ART_BASENAME" | sed -n 's/^stackwatch-prebuilt-\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' || true)"

if [[ -n "$ART_VER" ]]; then
  if [[ "$ART_VER" != "$BASE" ]]; then
    NEW_VER="$ART_VER"
  else
    IFS='.' read -r MAJ MIN PAT <<<"$BASE"
    PAT=$((PAT + 1))
    NEW_VER="${MAJ}.${MIN}.${PAT}"
  fi
else
  IFS='.' read -r MAJ MIN PAT <<<"${BASE}"
  PAT=$((PAT + 1))
  NEW_VER="${MAJ}.${MIN}.${PAT}"
fi

TAG="v${NEW_VER}"
echo "Determined new version tag: ${TAG}"

# 5) copy artifact and checksum into prod repo
cp "${WORKDIR}/${ART_BASENAME}" .
cp "${WORKDIR}/${ART_BASENAME}.sha256" .

# 6) add RELEASE_NOTES file
RELEASE_NOTES="Release ${TAG}\n\nPromoted from test: ${TEST_TAG}\n\nChecksum:\n$(cat ${ART_BASENAME}.sha256)\n"
echo -e "$RELEASE_NOTES" > RELEASE_NOTES_${TAG}.md

# 7) commit changes if any
git add "$(basename "$ART_BASENAME")" "$(basename "${ART_BASENAME}.sha256")" "RELEASE_NOTES_${TAG}.md" || true
if git status --porcelain | grep -q .; then
  git commit -m "Release ${TAG}: add artifact and checksum"
else
  echo "No changes to commit (artifact maybe same)"
fi

# 8) tag and push
git tag -a "${TAG}" -m "Release ${TAG} - checksum: $(cut -d' ' -f1 "${ART_BASENAME}.sha256")"
git push origin HEAD
git push origin "${TAG}"

# 9) optionally delete test tag from testing repo (needs testing repo SSH access)
if [[ -n "$TEST_TAG" ]]; then
  echo "Attempting to delete test tag ${TEST_TAG} from testing repo (if Jenkins key has access)..."
  # NOTE: replace <TESTING_REPO_SSH> below if you have testing repo URL; assuming Jenkins key can access both repos,
  # you can delete directly by pushing a delete ref to your testing repo. If not, skip or add the testing repo URL.
  # Example:
  # git push ssh://git@gitlab.assistanz24x7.com:223/stackwatch/stackwatch.git :refs/tags/${TEST_TAG} || true
fi

echo "Promotion complete. New tag: ${TAG}"
echo "Artifact: ${ART_BASENAME}"
echo "Checksum: $(cat ${ART_BASENAME}.sha256)"

# cleanup
cd /
rm -rf "$WORKDIR"


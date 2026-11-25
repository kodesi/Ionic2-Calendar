#!/usr/bin/env bash
# kodesi fork: builds the library and commits the built package to the `kodesi` branch.
#
# The Spiciko app installs this fork as a git dependency:
#   "ionic2-calendar": "git+https://github.com/kodesi/Ionic2-Calendar.git#<tag>"
# The npm package is the ng-packagr output in dist/, not the repo root, so the app can only
# install a branch whose root is that output. That is the `kodesi` branch: each commit on it
# is one build, made from a commit on a source branch (e.g. `ionic9`).
#
# Usage (from a clean checkout of the source branch):
#   scripts/kodesi-release.sh v2.8.0-kodesi.2
# then push the branch and the tag (origin must be kodesi/Ionic2-Calendar):
#   git push origin kodesi v2.8.0-kodesi.2
set -euo pipefail

tag="${1:?usage: $0 <tag>, e.g. v2.8.0-kodesi.2}"
cd "$(git rev-parse --show-toplevel)"

if [ -n "$(git status --porcelain)" ]; then
  echo "Commit or stash your changes first: the build must match a commit." >&2
  exit 1
fi
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "Tag $tag already exists." >&2
  exit 1
fi

src_branch=$(git rev-parse --abbrev-ref HEAD)
src_commit=$(git rev-parse --short HEAD)

npm ci
npm run build

# Commit dist/ as the whole tree of a new `kodesi` commit, through a temporary index so the
# source checkout is left untouched.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/kodesi-release.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
GIT_INDEX_FILE="$tmp/index" git -C dist --work-tree=. add -A .
tree=$(GIT_INDEX_FILE="$tmp/index" git write-tree)

parent=()
if git rev-parse -q --verify refs/heads/kodesi >/dev/null; then
  parent=(-p kodesi)
fi
commit=$(git commit-tree "$tree" ${parent[@]+"${parent[@]}"} \
  -m "Build $tag from $src_branch @ $src_commit" \
  -m "The built package (ng-packagr dist/) that the Spiciko app installs as a git dependency.")

git branch -f kodesi "$commit"
git tag -a "$tag" "$commit" -m "$tag, built from $src_branch @ $src_commit"

echo
echo "Built $tag on branch kodesi ($(git rev-parse --short "$commit")) from $src_branch @ $src_commit."
echo "Push it with: git push origin kodesi $tag"

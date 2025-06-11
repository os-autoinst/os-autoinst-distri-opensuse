#!/bin/bash
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Generates up-to-date list of LTP tests.
#
# Defaults to latest tag, but is possible to override to specific version tag:
# ```bash
# ./script/generate_ltp_runtest.sh \
#   "/tmp/ltp" \
#   "https://github.com/linux-test-project/ltp" \
#   "20250130"
# ```
#
# Run this script to update `data/publiccloud/ltp_runtest` with the latest LTP runtest entries:
# ```bash
# ./script/generate_ltp_runtest.sh > data/publiccloud/ltp_runtest
# ```
# Maintainer: QE C <qe-c@suse.de>
#
set -euo pipefail

DEFAULT_LTP_REPO_PATH="${1:-/tmp/ltp}"
LTP_REPO_URL="${2:-https://github.com/linux-test-project/ltp}"
TAG="${3:-}"

# Clone or update the LTP repo
if ! git -C "$DEFAULT_LTP_REPO_PATH" rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Cloning LTP repository..." >&2
    git clone --branch master --depth 1 "$LTP_REPO_URL" "$DEFAULT_LTP_REPO_PATH" >&2
fi

cd "$DEFAULT_LTP_REPO_PATH"
echo "Fetching tags in LTP repository..." >&2
git fetch --tags --quiet >&2

# Checkout specific tag or detect the latest
if [[ -z "$TAG" ]]; then
   TAG=$(git tag --sort=-creatordate | head -n 1)
fi

if ! git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Error: Specified tag '$TAG' not found in the repository." >&2
    exit 1    
fi

git checkout --quiet "$TAG"
TAG_COMMIT="$(git rev-parse HEAD)"

# Output header
cat <<EOF
# LTP runtest file for Public Cloud

# NOTE: Generated using the script below, against LTP:
# commit $TAG_COMMIT (tag: $TAG)
# Which is the HEAD of ltp-stable package from obs:
# https://build.opensuse.org/projects/benchmark:ltp:stable/packages/ltp-stable/files/_service

EOF

# Read and filter test definitions
DATA=()
TESTS=()

TMPFILE=$(mktemp)
cat runtest/{commands,containers,controllers,syscalls,cve} > "$TMPFILE"

while read -r LINE; do
    [[ -z $LINE || $LINE == \#* ]] && continue
    DATA+=("$LINE")
    TESTS+=("${LINE#* }")
done < "$TMPFILE"

rm -f "$TMPFILE"

# Detect duplicates
mapfile -t DUPS < <(printf "%s\n" "${TESTS[@]}" | sort | uniq -d)

# Output only lines with unique test script values
for LINE in "${DATA[@]}"; do
    TEST_NAME="${LINE#* }"
    DUP_FOUND=false
    for DUP in "${DUPS[@]}"; do
        if [[ "$TEST_NAME" == "$DUP" ]]; then
            DUP_FOUND=true
            break
        fi
    done
    if ! $DUP_FOUND; then
        echo "$LINE"
    fi
done

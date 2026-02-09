#!/bin/bash
# This script does the same as this script but using skopeo instead, so we can
# use it behind a pull-through cache registry to avoid DockerHub rate limits:
# https://github.com/moby/moby/blob/master/contrib/download-frozen-image-v2.sh

set -euo pipefail

if [ $# -lt 2 ]; then
	echo "usage: $0 dir image[:tag][@digest] ..." >&2
	exit 1
fi

DIR="$1"
shift
mkdir -p "$DIR"

ARCH="$(go env GOARCH)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' ERR EXIT

manifest_entries=()
repo_entries=()

for img in "$@"; do
	ref="${img%@*}"
	digest="${img##*@}"
	repo="${ref%%:*}"
	tag="${ref##*:}"

	if [[ "$repo" != */* ]]; then
		repo="docker.io/library/$repo"
	fi

	echo "Pulling ${repo}@${digest} for arch ${ARCH}"

	tarfile="$TMP/image.tar"

	# Force single-platform image to avoid "multiple images as a group"
	skopeo copy \
		--override-arch "$ARCH" \
		"docker://$repo@$digest" \
		"docker-archive:$tarfile:$repo:$tag"

	work="$TMP/extract"
	mkdir "$work"
	tar -xf "$tarfile" -C "$work"

	# Move layer + config blobs
	find "$work" -mindepth 1 -maxdepth 1 ! -name manifest.json ! -name repositories -exec mv -n {} "$DIR/" \;

	manifest_entries+=("$(jq -c '.[]' "$work/manifest.json")")
	repo_entries+=("$(jq -c 'to_entries[]' "$work/repositories")")

	rm -rf "$work" "$tarfile"
done

printf '%s\n' "${manifest_entries[@]}" | jq -s '.' > "$DIR/manifest.json"

printf '%s\n' "${repo_entries[@]}" | jq -s 'group_by(.key) | map({ (.[0].key): (map(.value) | add) }) | add' > "$DIR/repositories"

echo "Done. Docker image layout ready in $DIR"
echo "Load with: tar -cC \"$DIR\" . | docker load"

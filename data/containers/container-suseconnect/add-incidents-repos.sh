#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/incident_repos_file" >&2
  exit 1
fi

INCIDENT_REPOS_FILE="$1"

if [[ ! -f "$INCIDENT_REPOS_FILE" ]]; then
  echo "File not found: $INCIDENT_REPOS_FILE" >&2
  exit 1
fi

INCIDENT_REPOS_URLS="$(cat "$INCIDENT_REPOS_FILE")"

if [[ -z "${INCIDENT_REPOS_URLS//[[:space:]]/}" ]]; then
  echo "No incident repos specified, skipping." >&2
  exit 0
fi

IFS=',' read -r -a urls <<< "$INCIDENT_REPOS_URLS"

i=0
for url in "${urls[@]}"; do
  if [[ -z "$url" ]]; then
    continue
  fi

  i=$((i+1))
  alias="incident-$i"

  echo "Adding repo: $url as alias: $alias"
  zypper -n ar -f "$url" "$alias"
done
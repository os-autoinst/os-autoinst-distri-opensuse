#!/bin/bash
# Developer-only negative validation for the Grafana CVE checks.
#
# Runs a known vulnerable and a known fixed Grafana container on
# 127.0.0.1:3000, forces the version-gated check open, and asserts that the
# test fails on the vulnerable version and passes on the fixed one.
#
# This script is not part of TEST_FILES and is never downloaded to the SUT.
# It is meant for a laptop with podman or docker, from this directory:
#
#   ./validate_cve.sh
#   ENGINE=docker ./validate_cve.sh
#
# CVE-2021-43798 (plugin asset path traversal):
#   8.2.6 vulnerable, 8.2.7 fixed backport, 8.3.0 vulnerable, 8.3.1 fixed.
#   The script checks all four version pairs.

set -euo pipefail

cd "$(dirname "$0")"

ENGINE=${ENGINE:-podman}
FAKEBIN=$(mktemp -d)
CURRENT=

cleanup() {
    if [ -n "$CURRENT" ]; then
        $ENGINE rm -f "$CURRENT" >/dev/null 2>&1 || true
    fi
    rm -rf "$FAKEBIN"
}
trap cleanup EXIT

# The test starts grafana-server through systemctl. The container already
# runs Grafana, so a no-op systemctl keeps the fixture out of the way.
cat > "$FAKEBIN/systemctl" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$FAKEBIN/systemctl"

wait_health() {
    local tries=${1:-60}
    for _ in $(seq 1 "$tries"); do
        if curl -fsS -o /dev/null http://127.0.0.1:3000/api/health 2>/dev/null; then
            return 0
        fi
        sleep 2
    done
    return 1
}

run_case() {
    local version=$1 expected=$2
    local log="/tmp/grafana-cve-${version}.log"
    local rc

    CURRENT="grafana-cve-${version}"
    $ENGINE rm -f "$CURRENT" >/dev/null 2>&1 || true
    $ENGINE run -d --rm --name "$CURRENT" -p 127.0.0.1:3000:3000 \
        "docker.io/grafana/grafana:${version}" >/dev/null

    if ! wait_health; then
        echo "FAIL: Grafana ${version} did not become healthy"
        return 1
    fi

    set +e
    GRAFANA_TEST_FORCE_CVE=1 PATH="$FAKEBIN:$PATH" \
        python3 -m pytest -q test_grafana_security.py::test_plugin_path_traversal \
        >"$log" 2>&1
    rc=$?
    set -e

    $ENGINE rm -f "$CURRENT" >/dev/null 2>&1 || true
    CURRENT=

    if [ "$expected" = fail ] && [ "$rc" -ne 0 ]; then
        echo "PASS: Grafana ${version} -> test failed as expected"
        return 0
    fi
    if [ "$expected" = pass ] && [ "$rc" -eq 0 ]; then
        echo "PASS: Grafana ${version} -> test passed as expected"
        return 0
    fi

    echo "FAIL: Grafana ${version} -> unexpected test result (rc=${rc}), see ${log}"
    tail -20 "$log" || true
    return 1
}

run_case 8.2.6 fail
run_case 8.2.7 pass
run_case 8.3.0 fail
run_case 8.3.1 pass

#!/bin/bash
XFSTESTS_DIR='/opt/xfstests'
PROG="$XFSTESTS_DIR/check"
SCRIPT_DIR=$(realpath $(dirname "$0"))
OPTIONS=$2
DEEP_CLEAN=''
FSTYPE=''

# empty OPTIONS if it's not nfs or overlay, and store info to FSTYPE
case "$OPTIONS" in
    "-nfs")
        FSTYPE="nfs"
        ;;
    "-overlay")
        FSTYPE="overlay"
        ;;
    *)
        FSTYPE=$OPTIONS
        OPTIONS=""
        ;;
esac

if [ "$#" -eq 3 ]; then
    DEEP_CLEAN=$3
elif [ "$#" -eq 4 ]; then
    INJECT_LINE=$3
    INJECT_CODE=$4
elif [ "$#" -eq 5 ]; then
    DEEP_CLEAN=$3
    INJECT_LINE=$4
    INJECT_CODE=$5
fi

function usage()
{
    echo "Usage: $0 TEST [OPTIONS for ./check] [DEEP_CLEAN in wrapper] [INJECT_LINE(for debug)] [INJECT_CODE(for debug)]"
}

function unset_vars()
{
    unset TEST_DEV
    unset TEST_DIR
    unset SCRATCH_MNT
    unset SCRATCH_DEV_POOL
    unset SCRATCH_DEV
}

# Parse the output of "check"
# 1 - Test item
# 2 - Output to be parsed
function parse_result()
{
    # Is it skipped?
    echo "$2" | grep -i "Not run: $1" &> /dev/null
    if [[ $? -eq 0 ]]; then
        return 22
    fi
    # Is it failed?
    echo "$2" | grep -i "Failures: $1" &> /dev/null
    if [[ $? -eq 0 ]]; then
        return 1
    fi
    # Is it passed?
    echo "$2" | grep -i "Passed all 1 tests" &> /dev/null
    if [[ $? -eq 0 ]]; then
        return 0
    fi
    # Internal error
    return 11
}

# Inject code or set xtrace into subtests, could use in debugging
# 1 - Subtests to inject
# 2 - Line to inject
# 3 - Inject code, or else set as 'xtrace' to inject 'set -x' after
# inject line, and redirect debug info to /opt/log/xxx_xtrace.log
function inject_code()
{
    if [ "$3" != "xtrace" ]; then
        echo "DEBUG Mode: inject code ($3) into $1 line $2. Beware the output may not match after inject."
        sed -i "$2i$3" $XFSTESTS_DIR/tests/$1
    else
        echo "DEBUG Mode: inject 'set -x' into $1 after line $2. debug info will redirect to "$1_xtrace.log"."
        sed -i "$2iexec 42>/opt/log/$1_xtrace.log\nexport BASH_XTRACEFD=42\nset -x" $XFSTESTS_DIR/tests/$1
    fi
}

# Check XFSTESTS_DEEP_CLEAN to see if need clean up
# e.g. set osd XFSTESTS_DEEP_CLEAN='xfs/259,xfs/273-275'
function is_deep_clean_needed() {
    local current_test=$1
    [ -z "$DEEP_CLEAN" ] && return 1

    IFS=',' read -ra ADDR <<< "$DEEP_CLEAN"
    for entry in "${ADDR[@]}"; do
        if [[ $entry == *-* ]]; then
            local prefix=$(echo $entry | cut -d'/' -f1)
            local range=$(echo $entry | cut -d'/' -f2)
            local start=$(echo $range | cut -d'-' -f1)
            local end=$(echo $range | cut -d'-' -f2)

            local current_prefix=$(echo $current_test | cut -d'/' -f1)
            local current_num=$(echo $current_test | cut -d'/' -f2)

            if [[ "$prefix" == "$current_prefix" ]] && \
               [[ "$current_num" -ge "$start" ]] && \
               [[ "$current_num" -le "$end" ]]; then
                return 0
            fi
        elif [[ "$current_test" == "$entry" ]]; then
            return 0
        fi
    done
    return 1
}

# Cleanup for dirty log
function smart_clean() {
    local test_name=$1
    echo "[Wrapper] Starting cleanup for $test_name..."
    sync
    [ -b "$TEST_DEV" ] && blockdev --flushbufs "$TEST_DEV" 2>/dev/null
    if is_deep_clean_needed "$test_name"; then
        echo "[Wrapper] Deep clean for $test_name"
        # Clean TEST_DEV
        if mountpoint -q "$TEST_DIR"; then
            umount -f "$TEST_DIR" 2>/dev/null
        fi
        if [[ "$FSTYPE" == "xfs" ]] && [ -b "$TEST_DEV" ]; then
            xfs_repair -L "$TEST_DEV" &>/dev/null
            mount "$TEST_DEV" "$TEST_DIR"
        else
            mount "$TEST_DEV" "$TEST_DIR"
        fi
        # Clean SCRATCH_DEV
        for i in {1..5}; do
            local dev="/dev/loop$i"
            if [ -b "$dev" ]; then
                mountpoint -q "$dev" || mount | grep -q "$dev" && umount -l "$dev" 2>/dev/null
                blockdev --flushbufs "$dev" 2>/dev/null
            fi
        done
        sleep 2
    else
        if [[ "$FSTYPE" != "nfs" && "$FSTYPE" != "overlay" ]]; then
            [ -b "$SCRATCH_DEV" ] && umount -l "$SCRATCH_DEV" 2>/dev/null
        fi
    fi
}

# Check for cmdline arguments
if [ "$#" -lt 1 ]; then
    usage
    exit 255
fi
# Exit if xfstests not installed
if [[ ! -x "$PROG" ]]; then
    echo "[FAIL] xfstests not installed to /opt"
    exit 255
fi

# Fix hostname problem
grep -P "127\.0\.0\.1.*?$(hostname)" /etc/hosts &> /dev/null
if [[ $? -ne 0 ]]; then
    sed -i -e "s/127\\.0\\.0\\.1.*/& $(hostname)/g" /etc/hosts
fi
grep -P "::1.*?$(hostname)" /etc/hosts &> /dev/null
if [[ $? -ne 0 ]]; then
    sed -i -e "s/::1.*/& $(hostname)/g" /etc/hosts
fi

# Load xfstests settings from ~/.xfstests
if [[ -f "$HOME/.xfstests" ]]; then
    unset_vars
    source "$HOME/.xfstests"
fi

smart_clean "$1"

pushd "$XFSTESTS_DIR" &> /dev/null

if [ "$#" -gt 3 ]; then
    inject_code "$1" $INJECT_LINE "$INJECT_CODE"
fi

# Run test
log_file="/tmp/xfstests-$(echo "$1" | tr '/' '_').tmp"
./$(basename "$PROG") -d "$OPTIONS" "$1" | tee "$log_file"
output=$(cat "$log_file")
rm -f $log_file

parse_result "$1" "$output"
ret=$?

popd &> /dev/null
if [[ -f "$HOME/.xfstests" ]]; then
    unset_vars
fi
exit $ret

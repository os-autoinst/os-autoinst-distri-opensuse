#!/bin/bash
XFSTESTS_DIR='/opt/xfstests'
PROG="$XFSTESTS_DIR/check"
SCRIPT_DIR=$(realpath $(dirname "$0"))
FSTYPE=${2:-'xfs'}

function usage()
{
    echo "Usage: $0 TEST [FILESYSTEM TYPE]"
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

# Check for cmdline arguments
if [ "$#" -lt 1 -o "$#" -gt 2 ]; then
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

pushd "$XFSTESTS_DIR" &> /dev/null

# Umount /mnt/test and /mnt/scratch
umount $TEST_DEV &> /dev/null
if [[ -n "$SCRATCH_DEV_POOL" ]]; then
    for device in $SCRATCH_DEV_POOL; do
        umount $device &> /dev/null
    done
else
    umount $SCRATCH_DEV
fi

# Run test
log_file="/tmp/xfstests-$(echo "$1" | tr '/' '_').tmp"
./$(basename "$PROG") -d "$1" | tee "$log_file"
output=$(cat "$log_file")
rm -f $log_file

parse_result "$1" "$output"
ret=$?

popd &> /dev/null
if [[ -f "$HOME/.xfstests" ]]; then
    unset_vars
fi
exit $ret

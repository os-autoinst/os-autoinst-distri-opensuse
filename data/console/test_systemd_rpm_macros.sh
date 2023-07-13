#!/bin/bash -e

INPUT_FILE="systemd_rpm_macros_list"

echo "--------------------------------------------"
while read m; do
    echo "Testing $m..."
    rpm -E "$m"
    echo "--------------------------------------------"
done < "$INPUT_FILE"


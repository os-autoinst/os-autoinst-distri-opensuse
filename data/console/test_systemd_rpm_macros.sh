#!/bin/bash -e

INPUT_FILE="systemd_rpm_macros_list"

echo "--------------------------------------------"
for m in $(xargs < "$INPUT_FILE"); do
    echo "Testing $m..."
    rpm -E "$m"
    echo "--------------------------------------------"
done

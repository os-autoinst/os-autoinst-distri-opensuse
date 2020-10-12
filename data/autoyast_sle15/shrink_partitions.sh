#!/bin/bash

set -e -x

# Check if AutoYaST displayed a warning about shrinking partitions to make them
# fit (bsc#1078418).
zgrep "Some additional space" /var/log/YaST2/y2log*.gz
echo "AUTOYAST OK"

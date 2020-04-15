#!/bin/bash

## ==== Configuration ======================================================= ##

# Test disk size
DISK_SIZE="1G"
TEST_PATH="/var/tmp/sysbench"


## ==== Main ================================================================ ##

set -e

# Extract SLE version (e.g. 15.1) - needed for adding PackageHub
SLE_VERSION=`grep -Po 'VERSION_ID=\K.*' /etc/os-release | tr -d '"'`
# For now only x86_64 is supported
ARCH="x86_64"

echo "Installing sysbench ... "
# We
SUSEConnect -p PackageHub/${SLE_VERSION}/${ARCH}
zypper in -y sysbench

mkdir -p ${TEST_PATH}
cd ${TEST_PATH}

echo "Running IO stress tests ... "
sysbench fileio --file-total-size=${DISK_SIZE} prepare
sysbench fileio --file-total-size=${DISK_SIZE} --file-test-mode=rndrw --time=600 --max-requests=0 run
sysbench fileio --file-total-size=${DISK_SIZE} cleanup

echo "Running CPU stress tests ... "
sysbench cpu --cpu-max-prime=20000 --threads=4 run

echo "Running memory stress tests ... "
sysbench memory --threads=4 run

echo "[ OK ] Stress tests passed"

#!/bin/bash -e

disk=$1
dir=$2

export TEST_DIR=/mnt/test
export TEST_MNT=/mnt/test
export SCRATCH_DIR=/mnt/scratch
export SCRATCH_MNT=/mnt/scratch
export TEST_DEV=/dev/${disk}1
export SCRATCH_DEV=/dev/${disk}2
cd ${dir}
./check xfs/???

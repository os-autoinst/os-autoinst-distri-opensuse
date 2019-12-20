#!/bin/bash
# Copyright © 2019-2020 SUSE LLC
#
# pod_package_deps: bzip2, libbz2-devel, diffutils, coreutils, gcc
# pod_timeout: 30
#
# Port of bzip2 test from qa-testsuites.

# Autoinstall these files to temp directory:
OPENQA_TEST_FILES="bzip2/torepack/testfile.gz bzip2/tocompile/trivial.c bzip2/topack"

# Init test environment
source openqa_lib.sh
trap qa_fail ERR

# qa_bzip2_bigfilerun.sh
# ----------------------
qa_start_test "qa_bzip2_bigfilerun"
TEST_MBYTES="10"
echo "Starting compression of $TEST_MBYTES MBytes .."
dd if=/dev/urandom bs=1024 count=${TEST_MBYTES}k | bzip2 -z >/dev/null


# qa_bzip2_bznew.sh
# -----------------
bznew_test () {
	qa_start_test "qa_bzip2_bznew"

	if [ ! -x /usr/bin/bznew ] && [ "$(rpm -q bzip2 | cut -d\- -f 2)" -lt 103 ]; then
		echo "qa_bzip2_bznew cannot be run as bznew is not included in versions older than 1.0.3"
		qa_skip
	fi

	echo "Starting re-compression of testfile .."
	bznew *.gz
	ls -l *.bz2 >/dev/null
	test -e *.gz && echo "WARNING: old .gz-file was not removed" >&2
	rm -f *.bz2
}

bznew_test

# qa_bzip2_compile.sh
# -------------------
qa_start_test "qa_bzip2_compile"
echo "Start compiling.."
gcc -o trivial -lbz2 trivial.c
test -x trivial
./trivial

# qa_bzip2_validation.sh
# ----------------------
qa_start_test "qa_bzip2_validation Test #1 (default-settings)"
cp -r topack workdir
bzip2 workdir/*
ls workdir/*.bz2 >/dev/null
bzip2 -d workdir/*
diff -r topack workdir


for (( i=1; $i <= 9; i++ )); do
	qa_start_test "qa_bzip2_validation Test #2 (blocksize ${i}00k)"
	cp -r topack "blocksize-$i"
	bzip2 -$i "blocksize-$i"/*
	ls "blocksize-$i"/*.bz2 >/dev/null
	bzip2 -d "blocksize-$i"/*
	diff -r topack "blocksize-$i"
done


qa_start_test "qa_bzip2_validation Test #3 (bzip2-integritycheck)"
cp -r topack integrity
bzip2 integrity/*
ls integrity/*.bz2 >/dev/null
bzip2 --test integrity/*


qa_start_test "qa_bzip2_validation Test #4 (keep-setting)"
cp -r topack keep
bzip2 --keep keep/*
ls keep/*.bz2 >/dev/null

for NEWFILE in keep/*.bz2; do
	ORIG="${NEWFILE%.bz2}";
	BASEN="$(basename $ORIG)";
	test -e $ORIG
	cmp $ORIG topack/$BASEN
done

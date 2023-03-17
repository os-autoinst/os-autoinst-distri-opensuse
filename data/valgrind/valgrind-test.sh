#!/bin/bash -e
# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
# 
# Regression test for valgrind
# Maintainer: QE Core <qe-core@suse.de>

set -x # didn't work as part of the shebang

# Helper function to grep and ident the output
function GREP {
    grep "$@" | sed 's/^/   > /'
    status="${PIPESTATUS[0]}"
    if [[ $status != 0 ]]; then
        echo "[ERROR] 'grep $@' failed with status $status"
        exit 1
    fi
}

# Check for x86_64 architecture
# Place this before set -e as it fails on other platforms
x86_64=0
if [[ $(uname -m) == "x86_64" ]]; then
	x86_64=1
	echo "[INFO] x86_64 architecture detected"
fi


echo "Compiling test program ... "
# Disable -Wmaybe-uninitialized because we test a use of an uninitiazed memory.
gcc -Wall -Werror -Wextra -Wno-maybe-uninitialized -std=c99 -g2 -O0 -o valgrind-test valgrind-test.c

echo "Testing valgrind ... "
valgrind --tool=memcheck --trace-children=yes ./valgrind-test 2>/dev/null
valgrind --leak-check=full --show-leak-kinds=all --log-file="output_0.txt" ./valgrind-test --leak 2048 --leak 1024 --still-reachable 4096 2>/dev/null
GREP '3,072 bytes in 2 blocks are definitely lost in loss record 1 of 2' output_0.txt
GREP '4,096 bytes in 1 blocks are still reachable in loss record 2 of 2' output_0.txt
GREP 'leak_some_mem' output_0.txt
GREP 'definitely lost: 3,072 bytes in 2 blocks' output_0.txt
GREP 'still reachable: 4,096 bytes in 1 blocks' output_0.txt
valgrind --tool=memcheck --trace-children=yes  --log-file="output_1.txt" ./valgrind-test --fork --leak 1024 2>/dev/null
GREP 'in use at exit: 1,024 bytes in 1 blocks' output_1.txt
GREP 'total heap usage: 1 allocs, 0 frees, 1,024 bytes allocated' output_1.txt
GREP 'definitely lost: 1,024 bytes in 1 blocks' output_1.txt

valgrind --tool=memcheck --trace-children=yes  --log-file="output_2.txt" ./valgrind-test --leak 1024 --leak 1024 --leak 1024 2>/dev/null
GREP 'in use at exit: 3,072 bytes in 3 blocks' output_2.txt
GREP 'total heap usage: 3 allocs, 0 frees, 3,072 bytes allocated' output_2.txt
GREP 'definitely lost: 3,072 bytes in 3 blocks' output_2.txt

valgrind --tool=memcheck --leak-resolution=high --log-file="output_3.txt" ./valgrind-test --leak 1024 2>/dev/null
GREP 'in use at exit: 1,024 bytes in 1 blocks' output_3.txt
GREP 'total heap usage: 1 allocs, 0 frees, 1,024 bytes allocated' output_3.txt
GREP 'definitely lost: 1,024 bytes in 1 blocks' output_3.txt

valgrind --tool=memcheck --show-reachable=yes  --log-file="output_4.txt" ./valgrind-test --leak 1024 --leak 1024 --still-reachable 2048 2>/dev/null
GREP 'in use at exit: 4,096 bytes in 3 blocks' output_4.txt
GREP 'total heap usage: 3 allocs, 0 frees, 4,096 bytes allocated' output_4.txt
GREP 'definitely lost: 2,048 bytes in 2 blocks' output_4.txt
GREP 'still reachable: 2,048 bytes in 1 blocks' output_4.txt

valgrind --tool=memcheck --log-file="output_5.txt" ./valgrind-test 2>/dev/null
GREP 'All heap blocks were freed -- no leaks are possible' "output_5.txt"

valgrind --track-origins=yes --log-file="output_6.txt" ./valgrind-test --oob 256 40 2>/dev/null
GREP 'Invalid read of size' "output_6.txt"
GREP 'bytes after a block of size 256 alloc' "output_6.txt"
GREP 'Conditional jump or move depends on uninitialised value' "output_6.txt"
GREP 'Uninitialised value was created by a heap allocation' "output_6.txt"
GREP 'All heap blocks were freed -- no leaks are possible' "output_6.txt"

valgrind --track-origins=yes  --log-file="output_7.txt" ./valgrind-test --uninitialized 256
GREP 'Conditional jump or move depends on uninitialised value' "output_7.txt"
GREP 'Uninitialised value was created by a heap allocation' "output_7.txt"
GREP 'All heap blocks were freed -- no leaks are possible' "output_7.txt"

echo "Testing callgrind ... "
valgrind --tool=callgrind --callgrind-out-file="callgrind.out" ./valgrind-test 2>/dev/null
GREP '# callgrind format' callgrind.out
GREP 'version: ' callgrind.out
GREP 'creator: ' callgrind.out
GREP 'pid: ' callgrind.out
GREP 'cmd: ' callgrind.out
GREP 'desc: ' callgrind.out
GREP 'events: ' callgrind.out
GREP 'summary: ' callgrind.out
GREP 'totals: ' callgrind.out

echo "Testing cachegrind ... "
valgrind --tool=cachegrind --cachegrind-out-file="cachegrind.out" ./valgrind-test 2>/dev/null
GREP "desc: I1" cachegrind.out
GREP "desc: D1" cachegrind.out
GREP "desc: LL" cachegrind.out
GREP "cmd: " cachegrind.out
GREP "events: " cachegrind.out
GREP "summary: " cachegrind.out

echo "Testing helgrind ... "
valgrind -v --tool=helgrind ./valgrind-test 2>/dev/null
# Not output test, we rely on the correct execution and exit status

echo "Testing massif ... "
valgrind --tool=massif --massif-out-file="massif.out" ./valgrind-test 2>/dev/null
GREP 'desc:' massif.out
GREP 'cmd:' massif.out
GREP 'mem_heap_B=' massif.out
GREP 'mem_heap_extra_B=' massif.out
GREP 'heap_tree=' massif.out

rm -f output_{0..8}.txt callgrind.out cachegrind.out massif.out valgrind-test
echo -e "\n\n[ OK ] All Valgrind tests PASSED"

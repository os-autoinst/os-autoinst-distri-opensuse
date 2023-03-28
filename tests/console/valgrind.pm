# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gcc valgrind curl
# Summary: valgrind test
#          compile a test program and run valgrind to detect memory leaks on it
# - compile test program with gcc
# - Check if valgrind runs
# - Check if valgrind correctly detects memory leaks
# - Check if valgrind correctly detects memory leak from a forked child
# - Check if valgrind correctly detects memory leaks from a forked child
# - Check if valgrind correctly detects memory leaks that are still reachable
# - Check the valgrind tool "memcheck"
# - Check the valgrind tool "callgrind"
# - Check the valgrind tool "cachegrind"
# - Check the valgrind tool "helgrind"
# - Check the valgrind tool "massif"
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Logging;
use registration qw(cleanup_registration register_product add_suseconnect_product get_addon_fullname remove_suseconnect_product);
use version_utils "is_sle";

sub assert_present {
    my $text = shift;
    my $assert = shift;
    my $failmsg = shift // "Assertion failed: '$assert' not present";

    die $failmsg if ($text !~ $assert);
}

sub run {
    select_serial_terminal;
    prepare();
    record_info("valgrind", script_output("valgrind --version"));

    # Run valgrind memchecks
    assert_script_run 'valgrind --tool=memcheck --trace-children=yes ./valgrind-test';
    my $output = script_output('valgrind --leak-check=full --show-leak-kinds=all ./valgrind-test --leak 2048 --leak 1024 --still-reachable 4096');
    assert_present($output, '3,072 bytes in 2 blocks are definitely lost in loss record 1 of 2', "Loss record 1 is missing");
    assert_present($output, '4,096 bytes in 1 blocks are still reachable in loss record 2 of 2', "Loss record 2 is missing");
    assert_present($output, 'leak_some_mem', "leak_some_mem is not present");
    assert_present($output, 'definitely lost: 3,072 bytes in 2 blocks', "'definitely lost' not matching in output");
    assert_present($output, 'still reachable: 4,096 bytes in 1 blocks', "'still reachable' not matching in output");

    $output = script_output('valgrind --tool=memcheck --trace-children=yes ./valgrind-test --fork --leak 1024');
    assert_present($output, 'in use at exit: 1,024 bytes in 1 blocks', "In use not detected");
    assert_present($output, 'total heap usage: 1 allocs, 0 frees, 1,024 bytes allocated', "Heap statistics are wrong/unexpected");
    assert_present($output, 'definitely lost: 1,024 bytes in 1 blocks', "Definitely lost not detected");

    $output = script_output('valgrind --tool=memcheck --trace-children=yes ./valgrind-test --leak 1024 --leak 1024 --leak 1024');
    assert_present($output, 'in use at exit: 3,072 bytes in 3 blocks', "In use message mismatch");
    assert_present($output, 'total heap usage: 3 allocs, 0 frees, 3,072 bytes allocated', "heap stats are not matching");
    assert_present($output, 'definitely lost: 3,072 bytes in 3 blocks', "definitely lost is not matching");

    $output = script_output('valgrind --tool=memcheck --leak-resolution=high ./valgrind-test --leak 1024');
    assert_present($output, 'in use at exit: 1,024 bytes in 1 blocks', "'in use at exit' not matching in output");
    assert_present($output, 'total heap usage: 1 allocs, 0 frees, 1,024 bytes allocated', "'heap usage' mismatch in output");
    assert_present($output, 'definitely lost: 1,024 bytes in 1 blocks', "'definitely lost' mismatch in output");

    $output = script_output('valgrind --tool=memcheck --show-reachable=yes ./valgrind-test --leak 1024 --leak 1024 --still-reachable 2048');
    assert_present($output, 'in use at exit: 4,096 bytes in 3 blocks', "'in use at exit' not matching in output");
    assert_present($output, 'total heap usage: 3 allocs, 0 frees, 4,096 bytes allocated', "heap stats are not matching");
    assert_present($output, 'definitely lost: 2,048 bytes in 2 blocks', "'definitely lost' of 2 blocks mismatch in output");
    assert_present($output, 'still reachable: 2,048 bytes in 1 blocks', "'definitely lost' of 1 block mismatch in output");

    $output = script_output('valgrind --tool=memcheck ./valgrind-test');
    assert_present($output, 'All heap blocks were freed -- no leaks are possible', "'All heap blocks were freed' not matching in output");

    $output = script_output('valgrind --track-origins=yes ./valgrind-test --oob 256 40');
    assert_present($output, 'Invalid read of size', "Invalid read is not present");
    assert_present($output, 'bytes after a block of size 256 alloc', "block size output not matching");
    assert_present($output, 'Conditional jump or move depends on uninitialised value', "'conditional jump on uninitialised value' is not matching");
    assert_present($output, 'Uninitialised value was created by a heap allocation', "'uninitialised value by heap allocation' is not matching");
    assert_present($output, 'All heap blocks were freed -- no leaks are possible', "'all blocks freed' is not matching");

    $output = script_output('valgrind --track-origins=yes ./valgrind-test --uninitialized 256');
    assert_present($output, 'Conditional jump or move depends on uninitialised value', "'conditional jump on uninitialised value' is not matching");
    assert_present($output, 'Uninitialised value was created by a heap allocation', "'uninitialised value by heap allocation' is not matching");
    assert_present($output, 'All heap blocks were freed -- no leaks are possible', "'all blocks freed' is not matching");

    # callgrind tool checks
    assert_script_run('valgrind --tool=callgrind --callgrind-out-file="callgrind.out" ./valgrind-test');
    $output = script_output('cat callgrind.out');
    script_run('rm -f callgrind.out');
    assert_present($output, '# callgrind format', "'callgrind format' mismatch");
    assert_present($output, 'version: ', "'callgrind version' mismatch");
    assert_present($output, 'creator: ', "'callgrind creator' mismatch");
    assert_present($output, 'pid: ', "'callgrind pid' mismatch");
    assert_present($output, 'cmd: ', "'callgrind cmd' mismatch");
    assert_present($output, 'desc: ', "'callgrind desc' mismatch");
    assert_present($output, 'events: ', "'callgrind events' mismatch");
    assert_present($output, 'summary: ', "'callgrind summary' mismatch");
    assert_present($output, 'totals: ', "'callgrind totals' mismatch");

    # cachegrind tool checks
    assert_script_run('valgrind --tool=cachegrind --cachegrind-out-file="cachegrind.out" ./valgrind-test');
    $output = script_output('cat cachegrind.out');
    script_run('rm -f cachegrind.out');
    assert_present($output, "desc: I1", "'cachegrind desc I1' mismatch");
    assert_present($output, "desc: D1", "'cachegrind desc D1' mismatch");
    assert_present($output, "desc: LL", "'cachegrind desc LL' mismatch");
    assert_present($output, "cmd: ", "'cachegrind cmd' mismatch");
    assert_present($output, "events: ", "'cachegrind events' mismatch");
    assert_present($output, "summary: ", "'cachegrind summary' mismatch");

    # helgrind tool checks
    assert_script_run('valgrind -v --tool=helgrind ./valgrind-test');
    ## Since there is no output, we rely on the return value of the tool

    # massif tool checks
    assert_script_run('valgrind --tool=massif --massif-out-file="massif.out" ./valgrind-test');
    $output = script_output('cat massif.out');
    script_run('rm -f massif.out');
    assert_present($output, 'desc:', "massif 'desc' mismatch");
    assert_present($output, 'cmd:', "massif 'cmd' mismatch");
    assert_present($output, 'mem_heap_B=', "massif 'mem_heap_B' mismatch");
    assert_present($output, 'mem_heap_extra_B=', "massif 'mem_heap_extra_B' mismatch");
    assert_present($output, 'heap_tree=', "massif 'heap_tree' mismatch");

    assert_script_run 'cd';
    if (is_sle && !main_common::is_updates_tests()) {
        remove_suseconnect_product(get_addon_fullname('sdk'));    # unregister SDK
    }
}

sub prepare {
    # development module needed for dependencies, released products are tested with sdk module
    if (is_sle && !main_common::is_updates_tests()) {
        cleanup_registration;
        register_product;
        add_suseconnect_product(get_addon_fullname('desktop'));
        add_suseconnect_product(get_addon_fullname('sdk'));
    }

    zypper_call 'in gcc valgrind';

    # Compile the valgrind test program
    assert_script_run 'mkdir -p /var/tmp/valgrind';
    assert_script_run 'cd /var/tmp/valgrind';
    assert_script_run 'curl -v -o valgrind-test.c ' . data_url('valgrind/valgrind-test.c');
    # Ignore unititialized errors, as they are expected for this test case
    assert_script_run 'gcc -Wall -Werror -Wextra -Wno-maybe-uninitialized -std=c99 -g2 -O0 -o valgrind-test valgrind-test.c';
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    tar_and_upload_log('/var/tmp/valgrind', 'valgrind-failed.tar.bz2');
    script_run 'cd';
}
1;

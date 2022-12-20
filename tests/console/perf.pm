# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: perf
# Summary: Test basic perf functionality
# Maintainer: Orestis Nalmpantis <onalmpantis@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    select_serial_terminal;

    # test 1
    # Installing and testing options -a -d -p
    zypper_call('in perf', exitcode => [0, 102, 103, 106]) if (script_run("which perf") != 0);
    assert_script_run('perf stat -a -d -p 1 sleep 5');
    # test 2
    # Counting with perf stat
    assert_script_run('perf stat dd if=/dev/zero of=demo bs=4k count=10000');
    assert_script_run('perf record dd if=/dev/zero of=demo bs=4k count=10000');
    script_run('timeout 5 perf report -i perf.data');
    assert_script_run('perf trace ls');
    # test 3
    # Static Tracing (record command)
    assert_script_run('perf stat -e cs dd if=/dev/zero of=demo bs=4k count=10000');
    assert_script_run('perf record -e cs dd if=/dev/zero of=demo bs=4k count=10000');
    script_run('timeout 5 perf report -i perf.data');
    # test4
    # Dynamic Tracing (probe command)
    assert_script_run('perf probe --add tcp_sendmsg');
    script_run('perf record -e probe:tcp_sendmsg -aR sleep 10 ');
    script_run('timeout 5 perf report -i perf.data');
    assert_script_run('perf probe -d tcp_sendmsg');
    # test5
    # Counting Events ( stat command)
    assert_script_run('perf stat ls');
    assert_script_run('perf stat -a sleep 5');
    assert_script_run('perf stat -e cycles,instructions,cache-references,cache-misses,bus-cycles -a sleep 5');
    assert_script_run("perf stat -e 'syscalls:sys_enter_*' -a sleep 5");
    assert_script_run("perf stat -e 'block:*' -a sleep 10");
    # test6
    # Listing (list command)
    script_run('timeout 5 perf list sw');
    script_run('timeout 5 perf list');
}

1;

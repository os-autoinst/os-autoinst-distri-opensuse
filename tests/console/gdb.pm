
# SUSE's openQA tests
#
# Copyright (C) 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
# Package: gcc glibc-devel gdb sysvinit-tools
# Summary: Basic GDB test. (Breakpoints/backtraces/attaching)
# - Add sdk repository if necessary
# - Install gcc glibc-devel gdb
# - Download and compile "test1.c" from datadir
#   - Using gdb, insert a breakpoint at main, run test and check
# - Download and compile "test2.c" from datadir
#   - Using gdb, run program, get a backtrace info and check
# - Download and compile "test3.c" from datadir
#   - Run test3, attach gdb to its pid, add a breakpoint and check
# Maintainer: apappas@suse.de

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils qw(zypper_call);
use version_utils qw(is_leap is_sle);

sub wait_serial_or_die {
    my $feedback = shift;

    my $e = wait_serial($feedback, 10);
    if (!defined $e) {
        die("Unexpected serial output");
    }
}

sub run {
    my $self      = shift;
    my $test_deps = 'gcc glibc-devel gdb';

    $self->select_serial_terminal;
    # *pidof* binary is normally found in *procps* rpm
    # except of sle, where it is provided by *sysvinit-tools* rpm
    # since sle(15-SP3+) *sysvinit-tools* is not preinstalled on JeOS
    # as systemd's dependency with *sysvinit-tools* was dropped
    $test_deps .= ' sysvinit-tools' if (is_sle('>15-sp2') || is_leap('>15.2'));
    zypper_call("in $test_deps");

    #Test Case 1
    assert_script_run("curl -O " . data_url('gdb/test1.c'));
    assert_script_run("gcc -g -std=c99 test1.c -o test1");
    enter_cmd("gdb test1 | tee /dev/$serialdev");
    wait_serial_or_die("GNU gdb");
    #Needed because colour codes mess up the output on $serialdev
    enter_cmd("set style enabled 0");
    enter_cmd("break main");
    enter_cmd("run");
    wait_serial_or_die("Breakpoint 1, main");
    enter_cmd("continue");
    wait_serial_or_die("exited normally");
    enter_cmd("quit");

    #Test Case 2
    assert_script_run("curl -O " . data_url('gdb/test2.c'));
    assert_script_run("gcc -g -std=c99  test2.c -o test2");
    enter_cmd("gdb test2 | tee /dev/$serialdev");
    wait_serial_or_die(qr/GNU gdb/);
    enter_cmd("set style enabled 0");
    enter_cmd("run");
    wait_serial_or_die("Program received signal SIGSEGV");
    enter_cmd("backtrace");
    wait_serial_or_die(s.in main () at test2.c:16.);
    enter_cmd("info locals");
    enter_cmd("up");
    wait_serial_or_die(s.1 0x000000000040117b in main () at test2.c:16\n16 char * newstr = str_dup(cstr, 5);.);
    enter_cmd("info locals");
    wait_serial_or_die("<error: Cannot access memory at ");
    enter_cmd("quit");
    wait_serial_or_die("Inferior");
    enter_cmd("y");

    #Test 3
    assert_script_run("curl -O " . data_url('gdb/test3.c'));
    assert_script_run("gcc -g -std=c99 test3.c -o test3");
    script_run("./test3 & echo 'this is a workaround'");
    assert_script_run("pidof test3");    #Make sure the process was launched.
    enter_cmd("gdb -p \$(pidof test3) | tee /dev/$serialdev");
    wait_serial_or_die("Attaching to process", 10);
    enter_cmd("set style enabled 0");
    enter_cmd("break test3.c:9");
    wait_serial_or_die("Breakpoint 1 at");
    enter_cmd("continue");
    wait_serial_or_die(s.Breakpoint 1, main () at test3.c:9.);
    enter_cmd("quit");
    wait_serial("Quit anyway?");
    enter_cmd("y");
    enter_cmd("y");                      #Workaround to handle sshserial behavior
    assert_script_run("pkill -9 test3");
}

1;

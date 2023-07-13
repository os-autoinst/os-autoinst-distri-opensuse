
# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
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
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call);
use version_utils qw(is_leap is_sle);

sub wait_serial_or_die {
    my ($feedback, %args) = @_;
    $args{timeout} //= 10;

    my $e = wait_serial($feedback, %args);
    if (!defined $e) {
        die("Unexpected serial output");
    }
}

sub enter_gdb_cmd {
    my $cmd = shift;
    wait_serial_or_die('(gdb)', no_regex => 1);
    enter_cmd($cmd);
}

sub run {
    my $test_deps = 'gcc glibc-devel gdb';

    select_serial_terminal;
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
    wait_serial_or_die('GNU gdb');
    #Needed because colour codes mess up the output on $serialdev
    enter_gdb_cmd("set style enabled 0");
    enter_gdb_cmd("break main");
    enter_gdb_cmd("run");
    wait_serial_or_die("Breakpoint 1, main");
    enter_gdb_cmd("continue");
    wait_serial_or_die("exited normally");
    enter_gdb_cmd("quit");

    #Test Case 2
    assert_script_run("curl -O " . data_url('gdb/test2.c'));
    assert_script_run("gcc -g -std=c99  test2.c -o test2");
    enter_cmd("gdb test2 | tee /dev/$serialdev");
    wait_serial_or_die('GNU gdb');
    enter_gdb_cmd("set style enabled 0");
    enter_gdb_cmd("run");
    wait_serial_or_die("Program received signal SIGSEGV");
    enter_gdb_cmd("backtrace");
    wait_serial_or_die('in main \(\) at test2\.c:16');
    enter_gdb_cmd("info locals");
    enter_gdb_cmd("up");
    wait_serial_or_die(qr/1\s+.*\s+in main \(\) at test2\.c:16\s+16\s+char \* newstr = str_dup\(cstr, 5\);/);
    enter_gdb_cmd("info locals");
    wait_serial_or_die("<error: Cannot access memory at ");
    enter_gdb_cmd("quit");
    wait_serial_or_die("Inferior");
    enter_cmd("y");

    #Test 3
    assert_script_run("curl -O " . data_url('gdb/test3.c'));
    assert_script_run("gcc -g -std=c99 test3.c -o test3");
    script_run("./test3 & echo 'this is a workaround'");
    assert_script_run("pidof test3");    #Make sure the process was launched.
    enter_cmd("gdb -p \$(pidof test3) | tee /dev/$serialdev");
    wait_serial_or_die("Attaching to process", 10);
    enter_gdb_cmd("set style enabled 0");
    enter_gdb_cmd("break test3.c:9");
    wait_serial_or_die("Breakpoint 1 at");
    enter_gdb_cmd("continue");
    wait_serial_or_die('Breakpoint 1, main () at test3.c:9', no_regex => 1);
    enter_gdb_cmd("quit");
    wait_serial('Quit anyway?', no_regex => 1);
    enter_cmd("y");
    #Workaround to handle sshserial behavior
    check_var('SERIALDEV', 'sshserial') && enter_cmd("y");
    assert_script_run("pkill -9 test3");
}

1;

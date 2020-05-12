
# SUSE's openQA tests
#
# Copyright (C) 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
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
use utils 'zypper_call';
use version_utils;
use Utils::Architectures;
use registration;


sub wait_serial_or_die {
    my $feedback = shift;

    my $e = wait_serial($feedback, 10);
    if (!defined $e) {
        die("Unexpected serial output");
    }
}


sub run {
    #Setup console for text feedback.
    select_console("root-console");
    if (is_sle('=12-SP5') && is_aarch64()) {
        register_product;
        add_suseconnect_product 'sle-sdk';
    }
    zypper_call('in gcc glibc-devel gdb');    #Install test dependencies.

    #Test Case 1
    assert_script_run("curl -O " . data_url('gdb/test1.c'));
    assert_script_run("gcc -g -std=c99 test1.c -o test1");
    type_string("gdb test1 >/dev/$serialdev\n");
    wait_serial_or_die("GNU gdb");
    #Needed because colour codes mess up the output on $serialdev
    type_string("set style enabled 0\n");
    type_string("break main\n");
    type_string("run\n");
    wait_serial_or_die("Breakpoint 1, main");
    type_string("continue\n");
    wait_serial_or_die("exited normally");
    type_string("quit\n");

    #Test Case 2
    assert_script_run("curl -O " . data_url('gdb/test2.c'));
    assert_script_run("gcc -g -std=c99  test2.c -o test2");
    type_string("gdb test2 > /dev/$serialdev\n");
    wait_serial_or_die(qr/GNU gdb/);
    type_string("set style enabled 0\n");
    type_string("run\n");
    wait_serial_or_die("Program received signal SIGSEGV");
    type_string("backtrace\n");
    wait_serial_or_die(s.in main () at test2.c:16.);
    type_string("info locals\n");
    type_string("up\n");
    wait_serial_or_die(s.1 0x000000000040117b in main () at test2.c:16\n16 char * newstr = str_dup(cstr, 5);.);
    type_string("info locals\n");
    wait_serial_or_die("<error: Cannot access memory at ");
    type_string("quit\n");
    wait_serial_or_die("Inferior");
    type_string("y\n");


    #Test 3
    assert_script_run("curl -O " . data_url('gdb/test3.c'));
    assert_script_run("gcc -g -std=c99 test3.c -o test3");
    script_run("./test3 & echo 'this is a workaround'");
    assert_script_run("pidof test3");    #Make sure the process was launched.
    type_string('gdb -p $(pidof test3)' . " > /dev/$serialdev");
    type_string("\n");
    wait_serial_or_die("Attaching to process", 10);
    type_string("set style enabled 0\n");
    type_string("break test3.c:9\n");
    wait_serial_or_die("Breakpoint 1 at");
    type_string("continue\n");
    wait_serial_or_die(s.Breakpoint 1, main () at test3.c:9.);
    type_string("quit\n");
    wait_serial("Quit anyway?");
    type_string("y\n");
    type_string("y\n");                  #Workaround to handle sshserial behavior
    assert_script_run("pkill -9 test3");
    if (is_sle('=12-SP5') && is_aarch64()) {
        cleanup_registration;
    }
}

1;

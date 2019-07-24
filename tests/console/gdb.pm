# SUSE's openQA tests
#
# Copyright (C) 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
# Summary: Basic GDB test. (Breakpoints/backtraces/attaching)
# Maintainer: apappas@suse.de

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils;
use Utils::Architectures 'is_aarch64';
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
    my ($self) = @_;
    $self->select_serial_terminal();
    if (is_sle('=12-SP5') && is_aarch64()) {
        register_product;
        add_suseconnect_product 'sle-sdk';
    }
    zypper_call('in gcc glibc-devel gdb');    #Install test depedencies.

    #Test Case 1
    assert_script_run("curl -O " . data_url('gdb/test1.c'));
    assert_script_run("gcc -g -std=c99 test1.c -o test1");
    type_string("gdb test1\n");
    wait_serial_or_die("GNU gdb");
    type_string("break main\n");
    type_string("run\n");
    wait_serial_or_die("Breakpoint 1, main");
    type_string("continue\n");
    wait_serial_or_die("exited normally");
    type_string("quit\n");

    #Test Case 2
    assert_script_run("curl -O " . data_url('gdb/test2.c'));
    assert_script_run("gcc -g -std=c99  test2.c -o test2");
    type_string("gdb test2\n");
    wait_serial_or_die(qr/GNU gdb/);
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
    type_string('gdb -p $(pidof test3)');
    type_string("\n");
    wait_serial_or_die("Attaching to process", 10);
    type_string("break test3.c:9\n");
    wait_serial_or_die("Breakpoint 1 at");
    type_string("continue\n");
    wait_serial_or_die(s.Breakpoint 1, main () at test3.c:9.);
    type_string("quit\n");
    wait_serial_or_die("Quit anyway?");
    type_string("y\n");
    assert_script_run("pkill -9 test3");
    select_console("root-console");
    if (is_sle('12-SP5') && is_aarch64()) {
        cleanup_registration;
    }
}

1;

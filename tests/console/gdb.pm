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

sub wait_serial_or_croak {
    my $feedback = shift;

    my $e = wait_serial($feedback, 10);
    if (!defined $e) {
        croak("Unexpected serial output");
    }
}


sub run {
    #Setup console for text feedback.
    my ($self) = @_;
    $self->select_serial_terminal();

    zypper_call('in gcc glibc-devel gdb');    #Install test depedencies.

    #Test Case 1
    assert_script_run("curl -O " . data_url('gdb/test1.c'));
    assert_script_run("gcc -g -std=c99 test1.c -o test1");
    script_run("gdb test1");
    type_string("break main\n");
    type_string("run\n");
    wait_serial_or_croak("Breakpoint 1, main");
    type_string("continue\n");
    wait_serial_or_croak("exited normally");
    type_string("quit\n");

    #Test Case 2
    assert_script_run("curl -O " . data_url('gdb/test2.c'));
    assert_script_run("gcc -g -std=c99  test2.c -o test2");
    script_run("gdb test2");
    type_string("run\n");
    wait_serial_or_croak("Program received signal SIGSEGV");
    type_string("backtrace\n");
    wait_serial_or_croak(s.in main () at test2.c:16.);
    type_string("info locals\n");
    type_string("up\n");
    wait_serial_or_croak(s.1 0x000000000040117b in main () at test2.c:16\n16 char * newstr = str_dup(cstr, 5);.);
    type_string("info locals\n");
    wait_serial_or_croak("<error: Cannot access memory at ");
    type_string("quit\n");
    wait_serial_or_croak("Inferior");
    type_string("y\n");

    #Test 3
    assert_script_run("curl -O " . data_url('gdb/test3.c'));
    assert_script_run("gcc -g  -std=c99 test3.c -o test3");
    script_run("./test3 & echo 'this is a workaround'");
    assert_script_run("pidof test3");    #Make sure the process was launched.
    script_run('gdb -p $(pidof test3)');
    wait_serial_or_croak("Attaching to process", 10);
    type_string("break test3.c:9\n");
    wait_serial_or_croak("Breakpoint 1 at");
    type_string("continue\n");
    wait_serial_or_croak(s.Breakpoint 1, main () at test3.c:9.);
    type_string("quit\n");
    wait_serial_or_croak("Quit anyway?");
    type_string("y\n");
    assert_script_run("pkill -9 test3");
    select_console("root-console");
}

1;

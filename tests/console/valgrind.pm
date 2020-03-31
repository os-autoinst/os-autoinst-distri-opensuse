# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use registration qw(cleanup_registration register_product add_suseconnect_product get_addon_fullname remove_suseconnect_product);
use version_utils "is_sle";

sub run {
    # Preparation
    my $self = shift;
    $self->select_serial_terminal;
    # development module needed for dependencies, released products are tested with sdk module
    if (is_sle && !main_common::is_updates_tests()) {
        cleanup_registration;
        register_product;
        add_suseconnect_product(get_addon_fullname('sdk'));
    }
    # install requirements
    zypper_call 'in gcc valgrind';
    # run test script
    assert_script_run 'cd /var/tmp';
    assert_script_run 'curl -v -o valgrind-test.c ' . data_url('valgrind/valgrind-test.c');
    assert_script_run 'curl -v -o valgrind-test.sh ' . data_url('valgrind/valgrind-test.sh');
    assert_script_run 'bash -e valgrind-test.sh';
    # unregister SDK
    if (is_sle && !main_common::is_updates_tests()) {
        remove_suseconnect_product(get_addon_fullname('sdk'));
    }
}

1;

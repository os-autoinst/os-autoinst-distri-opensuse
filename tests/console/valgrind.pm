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

sub run {
    # Preparation
    select_serial_terminal;
    # development module needed for dependencies, released products are tested with sdk module
    if (is_sle && !main_common::is_updates_tests()) {
        cleanup_registration;
        register_product;
        add_suseconnect_product(get_addon_fullname('desktop'));
        add_suseconnect_product(get_addon_fullname('sdk'));
    }
    # install requirements
    zypper_call 'in gcc valgrind';
    # run test script
    assert_script_run 'mkdir /var/tmp/valgrind && cd /var/tmp/valgrind';
    assert_script_run 'curl -v -o valgrind-test.c ' . data_url('valgrind/valgrind-test.c');
    assert_script_run 'curl -v -o valgrind-test.sh ' . data_url('valgrind/valgrind-test.sh');
    assert_script_run 'bash -x valgrind-test.sh';    # script's shebang has -e, -x inside

    if (is_sle && !main_common::is_updates_tests()) {
        remove_suseconnect_product(get_addon_fullname('sdk'));    # unregister SDK
    }
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    tar_and_upload_log('/var/tmp/valgrind', 'valgrind-failed.tar.bz2');
}
1;

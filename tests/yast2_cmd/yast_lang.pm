# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-country
# Summary: yast language test
# List languages, set default and secondary languages
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;
    zypper_call "in yast2-country";
    validate_script_output 'yast language list', sub { m/(.*)de_DE(.*)it_IT(.*)/s };
    # The module asserts the language list and summary, not the installed
    # translations, and package operations are very slow under binary coverage.
    my $no_packages = get_var('BINARY_COVERAGE') ? 'no_packages' : '';
    assert_script_run("yast language set lang=de_DE languages=it_IT $no_packages", timeout => 300);
    validate_script_output 'yast language summary', sub { m/(.*)de_DE(.*)it_IT(.*)/s };
    assert_script_run("yast language set lang=en_US $no_packages", timeout => 300);
}

sub test_flags {
    return {fatal => 0, no_rollback => 1};
}

1;

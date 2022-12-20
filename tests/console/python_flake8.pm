# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
# Summary: Regression test for python-flake8
# Maintainer: QE-Core <qe-core@suse.de>


use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use registration 'is_phub_ready';

sub run {
    select_serial_terminal;
    # Package 'python3-flake8' requires PackageHub is available
    return unless is_phub_ready();

    # Make sure that python-flake8 is installed.
    # On SLE, this requires phub extension
    zypper_call 'in python3-flake8';

    # Test case 1: check if flake8 is functional
    assert_script_run('mkdir /tmp/empty_dir');
    assert_script_run('flake8 /tmp/empty_dir');

    # Test case 2: check if flake8 is working as expected
    assert_script_run('curl -O ' . data_url("python/sample.py"));
    # If flake8 supports the --color parameter. use it to turn off colored output
    script_run('flake8 --color=never /tmp/empty_dir && export COLOR="--color=never"');
    validate_script_output('flake8 $COLOR --exit-zero sample.py', sub { m/E265 block comment should start with '# '/ && m/F401 'os' imported but unused/ });
    script_run('rm sample.py');
    script_run('rmdir /tmp/empty_dir');
}

1;

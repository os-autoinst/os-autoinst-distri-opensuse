# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run hostname functional tests (hostname command, hostnamectl, validation)
# Maintainer: Zoltan Balogh <zbalogh@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use agnosticTestRunner;

sub run {
    select_serial_terminal;
    install_package('hostname', trup_continue => 1);

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testHostname',
            domain => 'console',
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

sub test_flags {
    return {no_rollback => 1};
}

1;

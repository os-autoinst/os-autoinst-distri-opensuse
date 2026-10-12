# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run openQA-agnostic zypper custom configuration tests
# Maintainer: Zoltan Balogh <zbalogh@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use agnosticTestRunner;

sub run {
    select_serial_terminal;

    my $test = agnosticTestRunner->new({
            language => 'shell',
            name => 'testZypperCustomConfig',
            domain => 'microos',
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

1;

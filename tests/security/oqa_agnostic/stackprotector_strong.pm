# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run openQA-agnostic pytest verifying CONFIG_STACKPROTECTOR_STRONG in the kernel
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64084, tc#1744070, poo#206535

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use agnosticTestRunner;

sub run {
    select_serial_terminal;

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testCCStackprotectorStrong',
            domain => 'security',
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

1;

# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run the openQA-agnostic console font test (vconsole
#          configuration, font file, localectl, systemd-vconsole-setup)
# Maintainer: Zoltan Balogh <zbalogh@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends qw(has_ttys);
use agnosticTestRunner;

sub run {
    # The console font only exists where there is a virtual console.
    if (!has_ttys()) {
        record_info('skip', 'No virtual console on this backend, the console font test does not apply');
        return;
    }
    select_serial_terminal;

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testConsoleFont',
            domain => 'console',
            run_timeout => 120,
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

sub test_flags {
    # fatal => 0: a font failure must not stop the rest of the
    # schedule on backends without snapshots (os-autoinst only stops
    # when fatal is undefined and snapshots are unavailable). The
    # module only reads the configuration and re-applies the font, so
    # there is no state to clean up.
    return {no_rollback => 1, fatal => 0};
}

1;

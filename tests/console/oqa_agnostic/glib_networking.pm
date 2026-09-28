# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run glib-networking upstream installed tests
# Maintainer: Zoltan Balogh <zbalogh@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use agnosticTestRunner;

sub run {
    select_serial_terminal;
    install_package('glib-networking-tests gnome-desktop-testing', trup_continue => 1);

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testGlibNetworking',
            domain => 'console',
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

1;

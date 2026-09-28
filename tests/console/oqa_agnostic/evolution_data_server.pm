# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run evolution-data-server upstream installed tests
# Maintainer: Zoltan Balogh <zbalogh@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use agnosticTestRunner;

sub run {
    select_serial_terminal;
    # glibc-gconv-modules-extra is needed for vCard character set conversion tests (e.g. KOI8-R)
    # dbus-1-daemon provides dbus-run-session for isolated D-Bus registry test services
    install_package('evolution-data-server-tests gnome-desktop-testing dbus-1-daemon glibc-gconv-modules-extra', trup_continue => 1);

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testEvolutionDataServer',
            domain => 'console',
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

1;

# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run openQA-agnostic unzip functional tests
# Package: unzip
# Maintainer: Vit Pelcak <vpelcak@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use agnosticTestRunner;

sub run {
    select_serial_terminal;
    # rpm -q exits non-zero (so script_run is truthy) when unzip is missing.
    # trup_apply applies the package before the version query below; the runner
    # later installs python3-pytest with trup_reboot, which may reboot anyway.
    install_package('unzip', trup_apply => 1) if script_run('rpm -q unzip');

    my $unzip_version = script_output(q(rpm -q --queryformat '%{VERSION}' unzip));
    record_info('unzip', "version $unzip_version");

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testUnzip',
            domain => 'console',
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

1;

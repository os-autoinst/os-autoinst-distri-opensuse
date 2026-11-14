# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run the Grafana functional and CVE regression tests over the HTTP API
# Maintainer: Zoltan Balogh <zbalogh@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_available_packages';
use registration 'is_phub_ready';
use utils 'zypper_search';
use version_utils qw(is_sle is_tumbleweed);
use agnosticTestRunner;

sub run {
    select_serial_terminal;

    if (!is_tumbleweed() && !is_sle()) {
        record_info('SKIP', 'Grafana is only packaged for Tumbleweed and SLE PackageHub');
        return;
    }
    if (!is_phub_ready()) {
        record_info('SKIP', 'PackageHub is not available');
        return;
    }

    # The SLE schedules add PackageHub before this module; Tumbleweed ships
    # Grafana in the main repository.
    my $available = zypper_search('-t package --match-exact grafana');
    if (!@{$available // []}) {
        record_info('SKIP', 'Grafana is not available in the configured repositories');
        return;
    }
    install_available_packages('grafana curl nmap openssl', trup_continue => 1, trup_reboot => 1);

    my $test = agnosticTestRunner->new({
            language => 'python',
            name => 'testGrafana',
            domain => 'console',
            # The artifact restarts grafana-server twice and uploads 130 MiB.
            run_timeout => 900,
            # The SLE schedules already activated PackageHub; registering it
            # again fails.
            skip_phub => 1,
        }
    );
    $test->setup()->run_test()->parse_results()->cleanup();
}

1;

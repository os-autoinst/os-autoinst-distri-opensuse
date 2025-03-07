# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dnsmasq
# Summary: Check basic dnsmasq resolving functionality
#          both with staticly configured queries and with
#          normal recursion.
#
# Maintainer: Ondřej Pithart <ondrej.pithart@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

use utils qw(zypper_call systemctl);

sub run {
    select_serial_terminal();
    zypper_call('in dnsmasq bind-utils');

    assert_script_run 'curl ' . data_url('console/dnsmasq.conf') . ' -o /etc/dnsmasq.conf';
    systemctl('enable --now dnsmasq');

    # Keys are DNS queries, values are regexes to be matched
    # against output of `dig $query`.
    my %records = (
        'openqa.domain.none' => 'A\s+11.22.33.44',
        'suse.de' => 'NXDOMAIN',
        'a.root-servers.net' => 'A\s+198.41.0.4',
        '-t PTR 4.0.41.198.in-addr.arpa' => 'PTR\s+a.root-servers.net',

        # only expect NOERROR because answers are changing
        'scc.suse.com' => 'status: NOERROR'
    );

    while (my ($query, $output) = each %records) {
        my $dig = script_output("dig \@127.0.0.1 $query");
        if ($dig !~ m/$output/) {
            die "expected output not foud. query: $query, expected match: $output";
        }
    }

    # cleanup
    systemctl('disable --now dnsmasq');
    assert_script_run('rm /etc/dnsmasq.conf');
}

1;

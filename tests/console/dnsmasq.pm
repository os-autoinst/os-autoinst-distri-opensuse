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
        # The root servers can change their IP addresses, but only in case of
        # great technical need. A change might occur once in 15+ years.
        # https://itp.cdn.icann.org/en/files/root-server-system-advisory-committee-rssac-publications/rssac-023-04nov16-en.pdf
        # Also the A root server has not changed once in it's existence
        # and is propagated from multiples sites using anycast propagation.
        'a.root-servers.net' => 'A\s+198.41.0.4',
        '-t PTR 4.0.41.198.in-addr.arpa' => 'PTR\s+a.root-servers.net',

        # only expect NOERROR because answers are changing
        'scc.suse.com' => 'status: NOERROR'
    );

    while (my ($query, $output) = each %records) {
        my $dig = script_output("dig \@127.0.0.1 $query");
        if ($dig !~ m/$output/) {
            # retry when query failed
            my $count = 1;
            if ($dig =~ m/status: SERVFAIL/) {
                die "query: $query returned status: SERVFAIL after ${count}th attempt" if $count > 19;
                $count++;
                record_info("Retry $count", 'Do query again due to status: SERVFAIL');
                sleep 2;
                redo;
            }
            die "expected output not foud. query: $query, expected match: $output";
        }
    }
}

sub cleanup {
    systemctl('disable --now dnsmasq');
    zypper_call('rm dnsmasq');
}

sub post_fail_hook {
    my ($self) = shift;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = shift;
    cleanup();
    $self->SUPER::post_run_hook;
}

1;

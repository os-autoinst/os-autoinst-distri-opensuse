# SUSE's openQA tests
#
# Copyright 2024,2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: netavark
# Summary: Upstream netavark integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use containers::bats;
use version_utils qw(is_sle is_tumbleweed);

my $netavark;

sub run_tests {
    my %env = (
        NETAVARK => $netavark,
    );

    my $log_file = "netavark.tap";

    return bats_tests($log_file, \%env, "");
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(aardvark-dns cargo firewalld iproute2 jq make protobuf-devel netavark);
    if (is_tumbleweed || is_sle('>=16.0')) {
        push @pkgs, qw(dbus-1-daemon);
    } elsif (is_sle) {
        push @pkgs, qw(dbus-1);
    }

    $self->bats_setup(@pkgs);

    $netavark = script_output "rpm -ql netavark | grep podman/netavark";
    record_info("netavark version", script_output("$netavark --version"));
    record_info("netavark package version", script_output("rpm -q netavark"));

    # Download netavark sources
    my $netavark_version = script_output "$netavark --version | awk '{ print \$2 }'";
    bats_sources $netavark_version;

    my $firewalld_backend = script_output "awk -F= '\$1 == \"FirewallBackend\" { print \$2 }' < /etc/firewalld/firewalld.conf";
    record_info("Firewalld backend", $firewalld_backend);

    # Compile helpers & patch tests
    run_command "make examples", timeout => 600;
    run_command "rm -f test/100-bridge-iptables.bats" if ($firewalld_backend ne "iptables");

    my $errors = run_tests;
    die "netavark tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;

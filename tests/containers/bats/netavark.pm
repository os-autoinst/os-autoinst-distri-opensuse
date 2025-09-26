# SUSE's openQA tests
#
# Copyright 2024,2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: netavark
# Summary: Upstream netavark integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use containers::bats;
use version_utils qw(is_sle);

my $netavark;

sub run_tests {
    my %env = (
        NETAVARK => $netavark,
    );

    my $log_file = "netavark";

    return bats_tests($log_file, \%env, "", 1200);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(aardvark-dns cargo firewalld iproute2 make ncat protobuf-devel netavark);
    push @pkgs, is_sle("<16") ? qw(dbus-1) : qw(dbus-1-daemon);

    $self->setup_pkgs(@pkgs);

    $netavark = script_output "rpm -ql netavark | grep podman/netavark";
    record_info("netavark version", script_output("$netavark --version"));
    record_info("netavark package version", script_output("rpm -q netavark"));

    # Download netavark sources
    my $netavark_version = script_output "$netavark --version | awk '{ print \$2 }'";
    patch_sources "netavark", "v$netavark_version", "test";

    my $firewalld_backend = script_output "awk -F= '\$1 == \"FirewallBackend\" { print \$2 }' < /etc/firewalld/firewalld.conf";
    record_info("Firewalld backend", $firewalld_backend);

    # Compile helpers & patch tests
    run_command "make examples", timeout => 600;

    unless (get_var("BATS_TESTS")) {
        run_command "rm -f test/100-bridge-iptables.bats" if ($firewalld_backend ne "iptables");
    }

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

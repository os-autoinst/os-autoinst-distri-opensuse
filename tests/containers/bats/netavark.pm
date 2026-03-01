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
use version_utils;
use version;
use containers::bats;

my $netavark;
my $version;

sub run_tests {
    my %env = (
        NETAVARK => $netavark,
    );

    my $log_file = "netavark";

    my @xfails = ();
    push @xfails, (
        # Test fails on SLES 15 which uses netavark 1.12.x
        "250-bridge-nftables.bats",
    ) if (version->parse(numeric_version($version)) < version->parse("1.14.0"));

    return bats_tests($log_file, \%env, \@xfails, 1200);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(aardvark-dns cargo firewalld iproute2 iptables make netavark protobuf-devel);
    push @pkgs, is_sle("<16") ? qw(dbus-1) : qw(dbus-1-daemon);

    $self->setup_pkgs(@pkgs);

    install_ncat if is_sle;

    $netavark = script_output "rpm -ql netavark | grep podman/netavark";
    record_info("netavark version", script_output("$netavark --version"));
    record_info("netavark package version", script_output("rpm -q netavark"));

    # Download netavark sources
    $version = script_output "$netavark --version | awk '{ print \$2 }'";
    patch_sources "netavark", "v$version", "test";

    my $firewalld_backend = script_output "awk -F= '\$1 == \"FirewallBackend\" { print \$2 }' < /etc/firewalld/firewalld.conf";
    record_info("Firewalld backend", $firewalld_backend);

    # Compile helpers & patch tests
    run_command "make examples", timeout => 600;
    unless (is_sle) {
        # This helper replaces ncat
        run_command "cargo build --bin netavark-connection-tester", timeout => 600;
        run_command "cp target/debug/netavark-connection-tester bin/";
    }

    unless (get_var("RUN_TESTS")) {
        if ($firewalld_backend ne "iptables") {
            run_command "rm -f test/100-bridge-iptables.bats";
            run_command "rm -f test/200-bridge-firewalld.bats";
        }
    }

    return if check_var("BATS_IGNORE", "all");
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

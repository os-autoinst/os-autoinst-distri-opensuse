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

    return bats_tests($log_file, \%env, \@xfails, 1200);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my @pkgs = qw(aardvark-dns cargo dbus-1-daemon firewalld iproute2 iptables make netavark protobuf-devel);

    $self->setup_pkgs(@pkgs);

    $netavark = script_output "rpm -ql netavark | grep podman/netavark";
    record_info("netavark version", script_output("$netavark --version"));
    record_info("netavark package version", script_output("rpm -q netavark"));

    $version = script_output "$netavark --version | awk '{ print \$2 }'";

    if (version->parse(numeric_version($version)) < version->parse("1.16.0")) {
        run_command "zypper --gpg-auto-import-keys -n install ncat";
        # Some tests use "nc" instead of "ncat" expecting ncat behaviour instead of netcat-openbsd
        run_command "ln -sf /usr/bin/ncat /usr/bin/nc";
    }

    # Download netavark sources
    patch_sources "netavark", "v$version", "test";

    # Compile helpers & patch tests
    run_command "make examples", timeout => 600;
    if (version->parse(numeric_version($version)) >= version->parse("1.16.0")) {
        # This helper replaces ncat
        run_command "cargo build --bin netavark-connection-tester", timeout => 600;
        run_command "cp target/debug/netavark-connection-tester bin/";
    }

    # This test was removed on netavark v2.0.0 and the default firewall backend is nftables
    run_command "rm -f test/100-bridge-iptables.bats" if (version->parse(numeric_version($version)) < version->parse("2.0.0"));

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

# SUSE's openQA tests
#
# Copyright 2024,2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: aardvark-dns
# Summary: Upstream aardvark-dns integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;
use version;
use containers::bats;

my $aardvark = "";
my $version;

sub run_tests {
    my $netavark = script_output "rpm -ql netavark | grep podman/netavark";

    my %env = (
        AARDVARK => $aardvark,
        NETAVARK => $netavark,
    );

    my $log_file = "aardvark";

    my @xfails = ();
    push @xfails, (
        # Test fails on SLES 15 which uses aardvard-dns 1.12.x
        "100-basic-name-resolution.bats::basic container - dns itself on container with ipaddress v6",
    ) if (version->parse(numeric_version($version)) < version->parse("1.14.0"));

    return bats_tests($log_file, \%env, \@xfails, 800);
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Install tests dependencies
    my @pkgs = qw(aardvark-dns firewalld iproute2 netavark podman socat);
    push @pkgs, is_sle("<16") ? qw(dbus-1) : qw(dbus-1-daemon);
    $self->setup_pkgs(@pkgs);

    $aardvark = script_output "rpm -ql aardvark-dns | grep podman/aardvark-dns";
    record_info("aardvark-dns version", script_output("$aardvark --version"));
    record_info("aardvark-dns package version", script_output("rpm -q aardvark-dns"));

    # Download aardvark sources
    $version = script_output "$aardvark --version | awk '{ print \$2 }'";
    patch_sources "aardvark-dns", "v$version", "test";

    return 0 if check_var("BATS_IGNORE", "all");
    my $errors = run_tests;
    die "ardvark-dns tests failed" if ($errors);
}

sub post_fail_hook {
    bats_post_hook;
}

sub post_run_hook {
    bats_post_hook;
}

1;

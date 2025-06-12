# SUSE's openQA tests
#
# Copyright 2024,2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: aardvark-dns
# Summary: Upstream aardvark-dns integration tests
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use containers::bats;
use version_utils qw(is_sle is_tumbleweed);

my $aardvark = "";

sub run_tests {
    my $netavark = script_output "rpm -ql netavark | grep podman/netavark";

    my %env = (
        AARDVARK => $aardvark,
        NETAVARK => $netavark,
    );

    my $log_file = "aardvark.tap";

    return bats_tests($log_file, \%env, "");
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Install tests dependencies
    my @pkgs = qw(aardvark-dns firewalld iproute2 jq netavark podman);
    if (is_tumbleweed || is_sle('>=16.0')) {
        push @pkgs, qw(dbus-1-daemon);
    } elsif (is_sle) {
        push @pkgs, qw(dbus-1);
    }

    $self->bats_setup(@pkgs);

    $aardvark = script_output "rpm -ql aardvark-dns | grep podman/aardvark-dns";
    record_info("aardvark-dns version", script_output("$aardvark --version"));
    record_info("aardvark-dns package version", script_output("rpm -q aardvark-dns"));

    # Download aardvark sources
    my $aardvark_version = script_output "$aardvark --version | awk '{ print \$2 }'";
    bats_sources $aardvark_version;

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

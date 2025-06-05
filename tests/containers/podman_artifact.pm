# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: podman artifact
# Summary: Test podman artifact
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal qw(select_serial_terminal);
use version_utils;

my $test_dir = "/tmp/test_artifact";

sub run {
    select_serial_terminal;

    my $test_file = "$test_dir/test_file";
    my $artifact = "test-artifact";

    assert_script_run "mkdir -p $test_dir";
    assert_script_run "touch $test_file";

    # Test add
    assert_script_run "podman artifact add $artifact $test_file";
    assert_script_run "! podman artifact add $artifact $test_file";

    # Test inspect
    validate_script_output "podman artifact inspect $artifact", qr/"Name": "$artifact"/;
    assert_script_run "! podman artifact inspect noexist";

    # Test ls
    validate_script_output "podman artifact ls", qr/$artifact/;

    # Test rm
    assert_script_run "podman artifact rm $artifact";
    assert_script_run "! podman artifact rm $artifact";

    assert_script_run "rm -rf $test_dir";
}

1;

sub cleanup() {
    script_run 'podman artifact ls -n --format "{{.Repository}}" | while read artifact ; do podman artifact rm $artifact ; done';
    script_run "rm -rf $test_dir";
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup;
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;
    cleanup;
    $self->SUPER::post_run_hook;
}

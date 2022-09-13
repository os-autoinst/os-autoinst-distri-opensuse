# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prepare SLEM on PublicCloud
#          This test run installs the required tools for the subsequent test runs.
#          If you need packages please add them in here to avoid unnecessary reboots during the test runs.
#
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::ssh_interactive 'select_host_console';

sub run {
    my ($self, $args) = @_;
    my $instance = $args->{my_instance};
    select_host_console();    # select console on the openQA VM, not the PC instance

    # Not needed atm
    return;

    # Install all necessary packages at once because we have a transactional system that requires rebooting
    my @pkgs = qw(podman);

    $instance->ssh_assert_script_run("sudo transactional-update -n pkg in @pkgs");
    $instance->softreboot();
}

sub test_flags {
    return {fatal => 1};
}

1;

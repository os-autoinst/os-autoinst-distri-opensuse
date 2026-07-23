# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Wait for the on-demand instance's guest registration (cloud-regionsrv-client) to complete
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::utils qw(is_ondemand);
use publiccloud::ssh_interactive qw(select_host_console);

sub run {
    my ($self, $args) = @_;

    select_host_console();    # select console on the host, not the PC instance

    return unless (is_ondemand);
    $args->{my_instance}->wait_for_guestregister();
}

sub test_flags {
    return {fatal => 1};
}

1;

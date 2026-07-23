# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test the network speed of the public cloud instance
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::ssh_interactive qw(select_host_console);

sub run {
    my ($self, $args) = @_;

    select_host_console();    # select console on the host, not the PC instance

    $args->{my_instance}->network_speed_test();
}

sub test_flags {
    return {fatal => 0};
}

1;

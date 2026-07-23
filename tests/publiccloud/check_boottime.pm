# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check the public cloud instance boot time against a threshold
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::ssh_interactive qw(select_host_console);

sub run {
    my ($self, $args) = @_;

    select_host_console();    # select console on the host, not the PC instance

    $args->{my_instance}->check_system_boottime();
}

sub test_flags {
    return {fatal => 1};
}

1;

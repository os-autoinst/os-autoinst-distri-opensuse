# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check cloud-init status on the public cloud instance
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::utils qw(is_cloudinit_supported);
use publiccloud::ssh_interactive qw(select_host_console);

sub run {
    my ($self, $args) = @_;

    select_host_console();    # select console on the host, not the PC instance

    return unless (is_cloudinit_supported && !get_var('PUBLIC_CLOUD_SKIP_INSTANCE_CHECKS'));
    $args->{my_instance}->check_cloudinit();
}

sub test_flags {
    return {fatal => 1};
}

1;

# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test to check for bsc#1205002
#
# Maintainer: <qa-c@suse.de>

use base "publiccloud::basetest";
use strict;
use warnings;
use testapi;
use utils;
use publiccloud::ec2;
use publiccloud::utils "is_ec2";
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self, $run_args) = @_;

    die("This test should run only on EC2") unless is_ec2();

    select_serial_terminal();

    $self->instance->ssh_assert_script_run("sudo grub2-mkconfig -o /boot/grub2/grub.cfg");

    $self->provider->stop_instance($self->instance);

    my $instance_type = get_var('PUBLIC_CLOUD_NEW_INSTANCE_TYPE', 't3a.large');
    $self->provider->change_instance_type($self->instance, $instance_type);

    $self->provider->start_instance($self->instance);

    # The instance changes its public IP address so the key must be rescanned
    $self->instance->wait_for_ssh(scan_ssh_host_key => 1);
    $self->instance->ssh_assert_script_run("echo we can login");
}

1;

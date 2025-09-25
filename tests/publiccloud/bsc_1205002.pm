# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test to check for bsc#1205002
#
# Maintainer: QE-C team <qa-c@suse.de>

use base "publiccloud::basetest";
use testapi;
use utils;
use publiccloud::ec2;
use publiccloud::utils "is_ec2";
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self, $run_args) = @_;

    die("This test should run only on EC2") unless is_ec2();

    select_serial_terminal();

    my $provider = $run_args->{my_provider};
    my $instance = $run_args->{my_instance};

    $instance->ssh_assert_script_run("sudo grub2-mkconfig -o /boot/grub2/grub.cfg");

    $provider->stop_instance($instance);

    my $instance_type = get_var('PUBLIC_CLOUD_NEW_INSTANCE_TYPE', 't3a.large');
    $provider->change_instance_type($instance, $instance_type);

    $provider->start_instance($instance);

    # The instance changes its public IP address so the key must be rescanned
    $instance->update_instance_ip();
    $instance->wait_for_ssh(scan_ssh_host_key => 1);
    $instance->ssh_assert_script_run("echo we can login");
}

1;

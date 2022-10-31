# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic DMS test
#
#   This test does the following
#    - Installs SLE15-Migration and sle15-activation
#    - Reboot the system
#    - Check the system version is the expected one
#
# Maintainer: Jesus Bermudez Velazquez <jesus.bv@suse.com>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use publiccloud::utils;

our $target_version = get_required_var('TARGET_VERSION');

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    my $provider = $self->provider_factory();
    my $instance = $provider->create_instance();
    $instance->wait_for_guestregister();
    registercloudguest($instance) if is_byos();

    record_info('INFO', $target_version);

    sleep 90;    # wait for a bit for zypper to be available

    record_info('installs SLE15-Migration and suse-migration-sle15-activation');

    $instance->run_ssh_command(cmd => "sudo zypper -n in SLES15-Migration suse-migration-sle15-activation", timeout => 300);
    record_info('system reboots');
    my ($shutdown_time, $startup_time) = $instance->softreboot(
        timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 400)
    );
    # migration finished and instance rebooted
    record_info('INFO', 'Checking the migration succeed');

    my $product_version = $instance->run_ssh_command(cmd => 'sudo cat /etc/os-release');
    record_info('INFO', $product_version);

    my $get_version_id_cmd = "grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '\"'";
    my $migrated_version = $instance->run_ssh_command(cmd => $get_version_id_cmd);
    record_info('new version', $migrated_version);

    die("Wrong version: expected: " . $target_version . ", got " . $migrated_version) if ($migrated_version ne $target_version);
}

1;

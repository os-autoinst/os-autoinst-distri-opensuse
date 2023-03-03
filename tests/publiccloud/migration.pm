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
our $not_clean_vm = get_var('PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE');

sub run {
    my ($self, $args) = @_;
    select_serial_terminal();
    my $provider = $args->{my_provider};
    my $instance = $provider->create_instance();
    $instance->wait_for_guestregister();
    registercloudguest($instance) if is_byos();

    register_addons_in_pc($instance);
    $instance->ssh_assert_script_run('sudo zypper ref; sudo zypper -n up', timeout => 300);

    record_info('INFO', $target_version);

    sleep 90;    # wait for a bit for zypper to be available

    record_info('installs SLE15-Migration and suse-migration-sle15-activation');

    # Upload distro_migration.log
    $instance->upload_log("/system-root/var/log/distro_migration.log", failok => 1);

    $instance->ssh_script_run(cmd => "sudo zypper -n in SLES15-Migration suse-migration-sle15-activation", timeout => 300);

    # Include debug mode
    if ($not_clean_vm) {
        $instance->ssh_script_run(cmd => 'sudo touch /etc/sle-migration-service.yml');
        $instance->ssh_script_run(cmd => 'echo \"verbose_migration: true\" | sudo tee -a /etc/sle-migration-service.yml');
        $instance->ssh_script_run(cmd => 'echo \"debug: true\" | sudo tee -a /etc/sle-migration-service.yml');
        $instance->ssh_script_run(cmd => 'sudo cat /etc/sle-migration-service.yml');
        record_info('INFO', 'created sle-migration-service.yml configuration');
    }

    record_info('system reboots');
    my ($shutdown_time, $startup_time) = $instance->softreboot(
        timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 400),
        ignore_wrong_pubkey => 1
    );

    # Upload distro_migration.log
    $instance->upload_log("/var/log/distro_migration.log", failok => 1);

    # migration finished and instance rebooted
    record_info('INFO', 'Checking the migration succeed');

    my $product_version = $instance->ssh_script_run(cmd => 'sudo cat /etc/os-release');
    record_info('INFO', $product_version);

    my $migrated_version = 'N/A';
    $migrated_version = $1 if $product_version =~ /^VERSION_ID="([\d\.]+)"/sm;
    record_info('new version', $migrated_version);

    die("Wrong version: expected: " . $target_version . ", got " . $migrated_version) if ($migrated_version ne $target_version);
}

1;

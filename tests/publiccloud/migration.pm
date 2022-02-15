 # SUSE's openQA tests
 #
 # Copyright 2016-2022 SUSE LLC
 # SPDX-License-Identifier: FSFAP

 # Summary: Basic DMS test
 #
 #   This test does the following
 #    - Installs SLE15-Migration and sle15-activation
 #    - Reboot the system
 #    - Check the system version is the expected one
 #
 # Maintainer: Jesus Bermudez Velazquez <jesus.bv@suse.com>

 use Mojo::Base 'publiccloud::ssh_interactive_init';
 use testapi;
 use strict;
 use warnings;
 use utils;
 use publiccloud::utils "select_host_console";

 our $target_version = get_var('TARGET_VERSION');

 sub run {
     my ($self, $args) = @_;
     my $instance;

     record_info('INFO', $target_version);
     record_info('INFO', get_var('TARGET_VERSION'));
     $instance = $self->{my_instance} = $args->{my_instance};

     $self->select_serial_terminal;
     sleep 90; # wait for a bit for zypper to be available

     record_info('installs SLE15-Migration and suse-migration-sle15-activation');

     $instance->run_ssh_command(cmd => "sudo zypper ref");
     $instance->run_ssh_command(cmd => "sudo zypper up");
     $instance->run_ssh_command(cmd => "sudo zypper in -y SLES15-Migration suse-migration-sle15-activation");
     record_info('system reboots');
     my ($shutdown_time, $startup_time) = $instance->softreboot(
	 timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 400)
	 );
     # migration finished and instance rebooted
     record_info('INFO', 'Checking the migration succeed');

     my $product_version = $instance->run_ssh_command(cmd => 'sudo cat /etc/os-release');
     record_info('INFO', $product_version);

     my $distro_log = $instance->run_ssh_command(cmd => 'sudo cat /var/log/distro_migration.log');

     record_info('INFO', $distro_log);
     my $get_version_id_cmd = "grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '\"'";
     # my $migrated_version   = script_output($get_version_id_cmd);
     my $migrated_version = $instance->run_ssh_command(cmd => $get_version_id_cmd);

     if ($migrated_version != $target_version) {
        my $message = "Wrong version: expected: " . $target_version . ", got " . $migrated_version;
        record_info('INFO', $message);
        $self->result('fail');
     }
     elsif ($migrated_version == $target_version) {
	 $self->result('OK');
     }
}

1;

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

 use Mojo::Base 'publiccloud::basetest';
 use testapi;
 use strict;
 use warnings;
 use utils;
 use publiccloud::utils;

 our $target_version = get_required_var('TARGET_VERSION');

 sub run {
     my ($self, $args) = @_;
     $self->select_serial_terminal;
     my $provider = $self->provider_factory();
     my $instance = $provider->create_instance();
     $instance->wait_for_guestregister() if is_ondemand();
  
     registercloudguest($instance) if (is_byos());

     record_info('INFO', $target_version);
     record_info('INFO', get_var('TARGET_VERSION'));

     sleep 90; # wait for a bit for zypper to be available

     record_info('zypper up and ref');

     $instance->run_ssh_command(cmd => "sudo zypper --non-interactive up", timeout => 300);
     $instance->run_ssh_command(cmd => "sudo zypper --non-interactive ref", timeout => 300);

     #wget the latest DMS Migration RPM Package
     my $url = get_var('PUBLIC_CLOUD_DMS_IMAGE_LOCATION');
     my $package = get_var('PUBLIC_CLOUD_DMS_PACKAGE');
     my $dms_repo_key_url = get_var('PUBLIC_CLOUD_DMS_REPO_KEY_URL');
     my $dms_repo_key = get_var('PUBLIC_CLOUD_DMS_REPO_KEY');
     my $dms_rpm = "$url"."$package";

     assert_script_run("wget $dms_rpm -O $package", 180);
     assert_script_run("wget $dms_repo_key_url -O $dms_repo_key", 180);

     my $ret_pack = $instance->scp('/root/terraform/' . $package, 'remote:' . '/tmp/' . $package, 100);
     my $ret_key  = $instance->scp('/root/terraform/' . $dms_repo_key, 'remote:' . '/tmp/' . $dms_repo_key, 100);

     #Install unpublished migration packages.
     #Download the rpm , Import key and Install rpm package

     record_info("installs $package and suse-migration-sle15-activation");
     $instance->run_ssh_command(cmd => "sudo rpm --import /tmp/$dms_repo_key", proceed_on_failure => 0);
     $instance->run_ssh_command(cmd => "sudo zypper in -y /tmp/$package", proceed_on_failure => 0);
     $instance->run_ssh_command(cmd => "sudo zypper in -y suse-migration-sle15-activation", proceed_on_failure => 0);
     record_info("Migration Log File", run_ssh_command(cmd => "cat /var/log/distro_migration.log", proceed_on_failure => 0));



     #Install published migration packages.
     #$instance->run_ssh_command(cmd => "sudo zypper in -y SLES15-Migration suse-migration-sle15-activation", proceed_on_failure => 1);
     #Reboot after Migration

     record_info('system reboots');
     my ($shutdown_time, $startup_time) = $instance->softreboot(
	 timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 400)
	 );

     # migration finished and instance rebooted
     record_info('INFO', 'Checking the migration succeed');

     my $product_version = $instance->run_ssh_command(cmd => 'sudo cat /etc/os-release');
     record_info('INFO', $product_version);

     # Validate migrated version
     my $get_version_id_cmd = "grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '\"'";
     my $migrated_version = $instance->run_ssh_command(cmd => $get_version_id_cmd);
     record_info('new version', $migrated_version);

     die("Wrong version: expected: " . $target_version . ", got " . $migrated_version) if ($migrated_version ne $target_version);
}

1;

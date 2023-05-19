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
use File::Basename;

our $target_version = get_required_var('TARGET_VERSION');
our $not_clean_vm   = get_var('PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE');

sub run {
    my ( $self, $args ) = @_;
    #Download unpublished DMS package and install rpm
    my $dms_rpm_url          = get_var('PUBLIC_CLOUD_DMS_RPM_URL');
    my $dms_rpm     = basename($dms_rpm_url);
    my $repo_key_url = get_var('PUBLIC_CLOUD_DMS_REPO_KEY_URL');
    my $repo_key     = basename($repo_key_url);
    my $pc_rpm           = get_var('PUBLIC_CLOUD_DMS_PC_RPM');
    my $pc_act_location       = get_var('PUBLIC_CLOUD_PC_ACT_LOCATION');
    my $act_rpm          = get_var('PUBLIC_CLOUD_DMS_ACT_RPM');
    my $act_url      = "$pc_act_location" . "$act_rpm";
    my $pc_url       = "$pc_act_location" . "$pc_rpm";
    record_info('DEBUG', $pc_url);
    record_info('DEBUG', $pc_act_location);

    my $tmp_repo         = "/tmp/sles15-mig-repo";

    select_serial_terminal();
    my $provider = $args->{my_provider};
    my $instance = $provider->create_instance();
    registercloudguest($instance) if is_byos();
    register_addons_in_pc($instance);

    my $versions_info = sprintf("Target version : %s\n DMS package: %s\n Activation package: %s\n PC package: %s",
                                $target_version, $dms_rpm, $act_rpm, $pc_rpm);
    record_info( 'DMS Versions', $versions_info);

    #Refresh and Update
    $instance->ssh_assert_script_run( 'sudo zypper ref; sudo zypper -n up',
        timeout => 1000 );

    sleep 90;    # wait for a bit for zypper to be available

    record_info('wget repokey and rpms');
    assert_script_run( "wget $repo_key_url -O /tmp/$repo_key", 180 );
    assert_script_run( "wget $dms_rpm_url -O /tmp/$dms_rpm",          180 );
    assert_script_run( "wget $act_url -O /tmp/$act_rpm",           180 );
    record_info('DEBUG', $pc_url);
    record_info('DEBUG', $pc_act_location);
    record_info('DEBUG', "wget $pc_url -O /tmp/$pc_rpm");
    assert_script_run( "wget $pc_url -O /tmp/$pc_rpm",             180 );

    #Create repo
    record_info('Creating local repo');
    $instance->run_ssh_command(
        cmd     => "sudo zypper in -y createrepo",
        timeout => 1000
    );
    $instance->run_ssh_command(
        cmd => "mkdir -p $tmp_repo/rpm/noarch $tmp_repo/rpm/x86_64" );

    #Upload scp the rpm packages and repokey to public cloud
    record_info('SCP repokey and rpm');
    my $remote_repo_key =
      $instance->scp( "/tmp/$repo_key", 'remote:' . "/tmp/$repo_key",
        200 );
    $instance->scp( "/tmp/$dms_rpm", 'remote:' . "$tmp_repo/rpm/x86_64/$dms_rpm", 4000 );
    $instance->scp( "/tmp/$act_rpm", 'remote:' . "$tmp_repo/rpm/noarch/$act_rpm", 300 );
    $instance->scp( "/tmp/$pc_rpm", 'remote:' . "/tmp/$pc_rpm", 300 );

    $instance->run_ssh_command( cmd => "cd $tmp_repo;createrepo -v ." );
    $instance->run_ssh_command( cmd =>
"sudo zypper addrepo --gpgcheck-allow-unsigned $tmp_repo SLES15-Migration-latest; sudo zypper lr -u"
    );

    # Upload distro_migration.log
    $instance->upload_log("/system-root/var/log/distro_migration.log", failok => 1);

    record_info("Import $remote_repo_key");
    $instance->run_ssh_command(
        cmd                => "sudo rpm --import /tmp/$repo_key",
        proceed_on_failure => 0
    );
    record_info("installs SLE15-Migration and suse-migration-sle15-activation");
    $instance->run_ssh_command(
        cmd =>
"sudo zypper in -y --from SLES15-Migration-latest SLES15-Migration suse-migration-sle15-activation",
        proceed_on_failure => 0
    );

    # Include debug mode
    if ($not_clean_vm) {
        $instance->ssh_script_run(
            cmd => 'sudo touch /etc/sle-migration-service.yml' );
        $instance->ssh_script_run( cmd =>
'echo \"verbose_migration: true\" | sudo tee -a /etc/sle-migration-service.yml'
        );
        $instance->ssh_script_run( cmd =>
'echo \"debug: true\" | sudo tee -a /etc/sle-migration-service.yml'
        );
        $instance->ssh_script_run(
            cmd => 'sudo cat /etc/sle-migration-service.yml' );
        record_info( 'INFO',
            'created sle-migration-service.yml configuration' );
     }

    record_info('Remove repo');
    $instance->run_ssh_command(
        cmd                => "sudo zypper rr SLES15-Migration-latest",
        proceed_on_failure => 0
    );

    record_info('system reboots');
    my ( $shutdown_time, $startup_time ) = $instance->softreboot(
        timeout             => get_var( 'PUBLIC_CLOUD_REBOOT_TIMEOUT', 400 ),
         ignore_wrong_pubkey => 1
     );

    # Upload distro_migration.log
    $instance->upload_log( "/var/log/distro_migration.log", failok => 1 );

    # migration finished and instance rebooted
    record_info('Migration Status', 'Checking the migration succeed');

    my $product_version =
      $instance->run_ssh_command( cmd => 'sudo cat /etc/os-release' );
    record_info( 'Product Version', $product_version );

    my $migrated_version = 'N/A';
    $migrated_version = $1
      if ( $product_version =~ /^VERSION_ID="([\d\.]+)"/sm );
    record_info( 'Migrated Version', $migrated_version );

    die(    "Wrong version: expected: "
          . $target_version
          . ", got "
          . $migrated_version )
      if ( $migrated_version ne $target_version );
}

1;

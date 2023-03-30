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
use Data::Dumper;

our $target_version = get_required_var('TARGET_VERSION');
our $not_clean_vm   = get_var('PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE');

sub run {
    my ( $self, $args ) = @_;
    select_serial_terminal();
    my $provider = $args->{my_provider};
    my $instance = $provider->create_instance();
    registercloudguest($instance) if is_byos();

    register_addons_in_pc($instance);
    record_info( 'Target Version', $target_version );

    sleep 90;    # wait for a bit for zypper to be available

    #Refresh and Update
    $instance->ssh_assert_script_run( 'sudo zypper ref; sudo zypper -n up',
        timeout => 1000 );

    #Download unpublished DMS package and install rpm
    my $dms_rpm          = get_var('PUBLIC_CLOUD_DMS_IMAGE_LOCATION');
    my $dms_rpm_name     = get_var('PUBLIC_CLOUD_DMS_RPM');
    my $pc_act_url       = get_var('PUBLIC_CLOUD_DMS_PC_ACT_LOCATION');
    my $dms_repo_key_url = get_var('PUBLIC_CLOUD_DMS_REPO_KEY_URL');
    my $dms_repo_key     = get_var('PUBLIC_CLOUD_DMS_REPO_KEY');
    my $pc_rpm           = get_var('PUBLIC_CLOUD_DMS_PC_RPM');
    my $act_rpm          = get_var('PUBLIC_CLOUD_DMS_ACT_RPM');
    my $dms_act_rpm      = "$pc_act_url" . "$act_rpm";
    my $dms_pc_rpm       = "$pc_act_url" . "$pc_rpm";
    my $tmp_repo         = "/tmp/sles15-mig-repo";

    record_info( "dms package name", $dms_rpm_name );
    record_info( "act package name", $act_rpm );
    record_info( "pc package name",  $pc_rpm );

    record_info('wget repokey and rpm');
    assert_script_run( "wget $dms_repo_key_url -O /tmp/$dms_repo_key", 180 );
    assert_script_run( "wget $dms_rpm -O /tmp/$dms_rpm_name",          180 );
    assert_script_run( "wget $dms_act_rpm -O /tmp/$act_rpm",           180 );
    assert_script_run( "wget $dms_pc_rpm -O /tmp/$pc_rpm",             180 );

    record_info('SCP repokey and rpm');

    #Download scp the rpm packages and repokey to public cloud
    my $repo_key =
      $instance->scp( "/tmp/$dms_repo_key", 'remote:' . "/tmp/$dms_repo_key",
        200 );
    my $dms_rpm_loc =
      $instance->scp( "/tmp/$dms_rpm_name", 'remote:' . "/tmp/$dms_rpm_name",
        4000 );
    my $dms_act_loc =
      $instance->scp( "/tmp/$act_rpm", 'remote:' . "/tmp/$act_rpm", 300 );
    my $dms_pc_loc =
      $instance->scp( "/tmp/$pc_rpm", 'remote:' . "/tmp/$pc_rpm", 300 );

    #Create repo/
    $instance->run_ssh_command(
        cmd     => "sudo zypper in -y createrepo",
        timeout => 1000
    );
    $instance->run_ssh_command(
        cmd => "mkdir -p $tmp_repo/rpm/noarch $tmp_repo/rpm/x86_64" );
    $instance->run_ssh_command( cmd =>
"cp -av /tmp/$dms_rpm_name $tmp_repo/rpm/x86_64/.; cp -av /tmp/$pc_rpm $tmp_repo/rpm/noarch/."
    );
    $instance->run_ssh_command( cmd => "cd $tmp_repo;createrepo -v ." );
    $instance->run_ssh_command( cmd =>
"sudo zypper addrepo --gpgcheck-allow-unsigned $tmp_repo SLES15-Migration-latest; sudo zypper lr -u"
    );

    # Upload distro_migration.log
    $instance->upload_log( "/system-root/var/log/distro_migration.log",
        failok => 1 );

    record_info('installs SLE15-Migration and suse-migration-sle15-activation');

    #Download scp the rpm packages and repokey to public cloud
    record_info("Import $dms_repo_key");
    $instance->run_ssh_command(
        cmd                => "sudo rpm --import /tmp/$dms_repo_key",
        proceed_on_failure => 0
    );
    record_info("installs SLE15-Migration and $act_rpm");
    $instance->run_ssh_command(
        cmd =>
"sudo zypper in -y --from SLES15-Migration-latest SLES15-Migration /tmp/$act_rpm",
        proceed_on_failure => 0
    );

#package installation is not required. rpms are installed above
#$instance->ssh_script_run(cmd => "sudo zypper -n in SLES15-Migration suse-migration-sle15-activation", timeout => 300);

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
    record_info( 'Migration Status', 'Checking the migration succeed' );

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

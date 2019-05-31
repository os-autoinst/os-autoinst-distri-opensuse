# SUSE's SLES4SAP openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install HANA via command line. Verify installation with
# sles4sap/hana_test
# Maintainer: Alvaro Carvajal <acarvajal@suse.com>

use base 'sles4sap';
use strict;
use warnings;
use testapi;

sub upload_install_log {
    script_run "tar -zcvf /tmp/hana_install.log.tgz /var/tmp/hdb*";
    upload_logs "/tmp/hana_install.log.tgz";
}

sub run {
    my ($self) = @_;
    my ($proto, $path) = $self->fix_path(get_required_var('MEDIA'));

    my $sid      = get_required_var('INSTANCE_SID');
    my $instid   = get_required_var('INSTANCE_ID');
    my $password = 'Qwerty_123';
    set_var('PASSWORD', $password);

    $self->select_serial_terminal;
    my $RAM = $self->get_total_mem();
    die "RAM=$RAM. The SUT needs at least 24G of RAM" if $RAM < 24000;

    # Add host's IP to /etc/hosts
    my $netdevice = get_var('SUT_NETDEVICE', 'eth0');
    assert_script_run "echo \$(ip -4 addr show dev $netdevice | sed -rne '/inet/s/[[:blank:]]*inet ([0-9\\.]*).*/\\1/p') \$(hostname) >> /etc/hosts";

    # This installs HANA. Start by configuring the appropiate SAP profile
    $self->prepare_profile('HANA');

    # Copy media
    my $tout = get_var('HANA_INSTALLATION_TIMEOUT', 1800);    # Timeout for HANA installation commands. Defaults to NW's timeout times 2
    $self->copy_media($proto, $path, $tout, '/sapinst');

    # Prepare mount points. Use the same sizes and names as the ones used by the wizard installation
    my %mountpts = (
        hanadata   => {mountpt => '/HANA/data',         size => '24g'},
        hanalog    => {mountpt => '/HANA/log',          size => '12g'},
        hanashared => {mountpt => '/HANA/shared',       size => '24g'},
        usr_sap    => {mountpt => "/usr/sap/$sid/home", size => '50g'}
    );

    # If running on QEMU and with a second disk configured, then configure
    # mountpoints and LVM. Otherwise leave those choices to hdblcm, but
    # always create mountpoints.
    foreach (keys %mountpts) { assert_script_run "mkdir -p $mountpts{$_}->{mountpt}"; }
    if (check_var('BACKEND', 'qemu') and get_var('HDDSIZEGB_2')) {
        my $device = check_var('HDDMODEL', 'scsi-hd') ? '/dev/sdb' : '/dev/vdb';
        script_run "wipefs -f $device; wipefs -f ${device}1";
        assert_script_run "parted --script $device --wipesignatures -- mklabel gpt mkpart primary 1 -1";
        $device .= '1';
        assert_script_run "pvcreate -y $device";
        assert_script_run "vgcreate -f vg_hana $device";
        foreach my $mounts (keys %mountpts) {
            assert_script_run "lvcreate -y -W y -n lv_$mounts --size $mountpts{$mounts}->{size} vg_hana";
            assert_script_run "mkfs.xfs /dev/vg_hana/lv_$mounts";
            assert_script_run "mount /dev/vg_hana/lv_$mounts $mountpts{$mounts}->{mountpt}";
        }
    }
    assert_script_run "df -h";

    # Check we have an hdblcm
    my $hdblcm = "/sapinst/DATA_UNITS/HDB_SERVER_LINUX_" . uc(get_required_var('ARCH')) . "/hdblcm";
    my $ret    = script_run "ls $hdblcm";
    if ($ret and get_var('OFW')) {
        # Some older versions of hana for ppc64le have hdblcm in HDB_SERVER_LINUX_PPC64 instead
        $hdblcm = "/sapinst/DATA_UNITS/HDB_SERVER_LINUX_PPC64/hdblcm";
        $ret    = script_run "ls $hdblcm";
    }
    die "hdblcm is not in $hdblcm" unless (defined $ret and $ret == 0);

    # Install hana
    my @hdblcm_args = qw(--autostart=n --shell=/bin/sh --workergroup=default --system_usage=custom --batch
      --hostname=$(hostname) --db_mode=multiple_containers --db_isolation=low --restrict_max_mem=n
      --userid=1001 --groupid=79 --use_master_password=n --skip_hostagent_calls=n --system_usage=production);
    push @hdblcm_args, "--sid=$sid", "--number=$instid", "--home=$mountpts{usr_sap}->{mountpt}",
      "--password=$password", "--system_user_password=$password", "--sapadm_password=$password",
      "--datapath=$mountpts{hanadata}->{mountpt}/$sid", "--logpath=$mountpts{hanalog}->{mountpt}/$sid",
      "--sapmnt=$mountpts{hanashared}->{mountpt}";
    my $cmd = join(' ', $hdblcm, @hdblcm_args);
    assert_script_run $cmd, $tout;

    upload_install_log;

    assert_script_run 'mount';
    assert_script_run 'lvs -ao +devices';
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal();
    upload_install_log;
    assert_script_run "save_y2logs /tmp/y2logs.tar.xz";
    upload_logs "/tmp/y2logs.tar.xz";
    $self->SUPER::post_fail_hook;
}

1;

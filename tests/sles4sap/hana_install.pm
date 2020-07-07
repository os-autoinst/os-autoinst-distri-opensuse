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
use utils qw(file_content_replace zypper_call);
use version_utils 'is_sle';
use POSIX 'ceil';

sub is_multipath {
    return (get_var('MULTIPATH') and (get_var('MULTIPATH_CONFIRM') !~ /\bNO\b/i));
}

sub get_hana_device_from_system {
    my ($self, $disk_requirement) = @_;

    # Create a list of devices already configured as PVs to exclude them from the search
    my $out = script_output q@echo PV=$(pvscan -s 2>/dev/null | awk '/dev/ {print $1}' | tr '\n' ',')@;
    $out =~ /PV=(.+),$/;
    $out = $1;
    my @pvdevs = map { if ($_ =~ s@mapper/@@) { $_ =~ s/\-part\d+$// } else { $_ =~ s/\d+$// } $_ =~ s@^/dev/@@; $_; } split(/,/, $out);

    my $lsblk = q@lsblk -n -l -o NAME -d -e 7,11 | egrep -vw '@ . join('|', @pvdevs) . "'";
    # lsblk command to probe for devices is different when in multipath scenario
    $lsblk = q@lsblk -l -o NAME,TYPE -e 7,11 | awk '($2 == "mpath") {print $1}' | sort -u | egrep -vw '@ . join('|', @pvdevs) . "'" if is_multipath();

    # Probe devices, check its size and filter out the ones that do not meet the disk requirements
    my $devsize = 0;
    my $devpath = is_multipath() ? '/dev/mapper/' : '/dev/';
    my $device;
    my $filter_devices;
    while ($devsize < $disk_requirement) {
        $out = script_output "echo DEV=\$($lsblk | egrep -vw '$filter_devices' | head -1)";
        $out =~ /DEV=([\w\.]+)$/;
        $device = $1;
        $filter_devices .= "|$device";
        $filter_devices =~ s/^|//;
        $device = $devpath . $device;

        # Need to verify there is enough space in the device for HANA
        $out = script_output "echo SIZE=\$(lsblk -o SIZE --nodeps --noheadings --bytes $device)";
        $out =~ /SIZE=(\d+)$/;
        $devsize = $1;
        $devsize /= (1024 * 1024);    # Work in Mbytes since $RAM = $self->get_total_mem() is in Mbytes
    }

    return $device;
}

sub run {
    my ($self) = @_;
    my ($proto, $path) = $self->fix_path(get_required_var('HANA'));
    my $sid    = get_required_var('INSTANCE_SID');
    my $instid = get_required_var('INSTANCE_ID');

    $self->select_serial_terminal;
    my $RAM = $self->get_total_mem();
    die "RAM=$RAM. The SUT needs at least 24G of RAM" if $RAM < 24000;

    zypper_call('in SAPHanaSR SAPHanaSR-doc ClusterTools2') if get_var('HA_CLUSTER');

    # Add host's IP to /etc/hosts
    $self->add_hostname_to_hosts;

    # Install libopenssl1_0_0 for older (<SPS03) HANA versions on SLE15+
    $self->install_libopenssl_legacy($path);

    # This installs HANA. Start by configuring the appropiate SAP profile
    $self->prepare_profile('HANA');

    # Copy media
    my $tout = get_var('HANA_INSTALLATION_TIMEOUT', 2700);    # Timeout for HANA installation commands. Defaults to NW's timeout times 2
    $self->copy_media($proto, $path, $tout, '/sapinst');

    # Mount points information: use the same paths and minimum sizes as the wizard (based on RAM size)
    my $full_size = ceil($RAM / 1024);                        # Use the ceil value of RAM in GB
    my $half_size = ceil($full_size / 2);
    my %mountpts  = (
        hanadata   => {mountpt => '/hana/data',         size => "${full_size}g"},
        hanalog    => {mountpt => '/hana/log',          size => "${half_size}g"},
        hanashared => {mountpt => '/hana/shared',       size => "${full_size}g"},
        usr_sap    => {mountpt => "/usr/sap/$sid/home", size => '50g'}
    );

    # Partition disks for Hana
    if (check_var('HANA_PARTITIONING_BY', 'yast')) {
        my $yast_partitioner = is_sle('15+') ? 'sap_create_storage_ng' : 'sap_create_storage';
        assert_script_run "yast $yast_partitioner /usr/share/YaST2/include/sap-installation-wizard/hana_partitioning.xml", 120;
    }
    else {
        # If running on QEMU and with a second disk configured, then configure
        # mountpoints and LVM. Otherwise leave those choices to hdblcm. If running
        # in a different backend, assume sdb exists. Always create mountpoints.
        foreach (keys %mountpts) { assert_script_run "mkdir -p $mountpts{$_}->{mountpt}"; }
        if ((check_var('BACKEND', 'qemu') and get_var('HDDSIZEGB_2')) or !check_var('BACKEND', 'qemu')) {
            # We need 2.5 times $RAM + 50G for HANA installation.
            my $device = $self->get_hana_device_from_system(($RAM * 2.5) + 50000);
            record_info "Device: $device", "Will use device [$device] for HANA installation";
            script_run "wipefs -f $device; [[ -b ${device}1 ]] && wipefs -f ${device}1; [[ -b ${device}-part1 ]] && wipefs -f ${device}-part1";
            assert_script_run "parted --script $device --wipesignatures -- mklabel gpt mkpart primary 1 -1";
            $device .= is_multipath() ? '-part1' : '1';
            assert_script_run "pvcreate -y $device";
            assert_script_run "vgcreate -f vg_hana $device";
            foreach my $mounts (keys %mountpts) {
                assert_script_run "lvcreate -y -W y -n lv_$mounts --size $mountpts{$mounts}->{size} vg_hana";
                assert_script_run "mkfs.xfs -f /dev/vg_hana/lv_$mounts";
                assert_script_run "mount /dev/vg_hana/lv_$mounts $mountpts{$mounts}->{mountpt}";
                assert_script_run "echo /dev/vg_hana/lv_$mounts $mountpts{$mounts}->{mountpt} xfs defaults 0 0 >> /etc/fstab";
            }
        }
    }
    assert_script_run "df -h";

    # hdblcm is used for installation, verify if it exists
    my $hdblcm = '/sapinst/' . get_var('HANA_HDBLCM', "DATA_UNITS/HDB_SERVER_LINUX_" . uc(get_required_var('ARCH')) . "/hdblcm");
    die "hdblcm is not in [$hdblcm]. Set HANA_HDBLCM to the appropiate relative path. Example: DATA_UNITS/HDB_SERVER_LINUX_X86_64/hdblcm"
      if (script_run "ls $hdblcm");

    # Install hana
    my @hdblcm_args = qw(--autostart=n --shell=/bin/sh --workergroup=default --system_usage=custom --batch
      --hostname=$(hostname) --db_mode=multiple_containers --db_isolation=low --restrict_max_mem=n
      --userid=1001 --groupid=79 --use_master_password=n --skip_hostagent_calls=n --system_usage=production);
    push @hdblcm_args,
      "--sid=$sid",
      "--number=$instid",
      "--home=$mountpts{usr_sap}->{mountpt}",
      "--password=$sles4sap::instance_password",
      "--system_user_password=$sles4sap::instance_password",
      "--sapadm_password=$sles4sap::instance_password",
      "--datapath=$mountpts{hanadata}->{mountpt}/$sid",
      "--logpath=$mountpts{hanalog}->{mountpt}/$sid",
      "--sapmnt=$mountpts{hanashared}->{mountpt}";
    my $cmd = join(' ', $hdblcm, @hdblcm_args);
    assert_script_run $cmd, $tout;

    # Enable autostart of HANA HDB, otherwise DB will be down after the next reboot
    # NOTE: not on HanaSR, as DB is managed by the cluster stack
    unless (get_var('HA_CLUSTER')) {
        my $hostname = script_output 'hostname';
        file_content_replace("$mountpts{hanashared}->{mountpt}/${sid}/profile/${sid}_HDB${instid}_${hostname}", '^Autostart[[:blank:]]*=.*' => 'Autostart = 1');
    }

    # Upload installations logs
    $self->upload_hana_install_log;

    # Quick check of block/filesystem devices after installation
    assert_script_run 'mount';
    assert_script_run 'lvs -ao +devices';
}

sub test_flags {
    return {fatal => 1};
}

1;

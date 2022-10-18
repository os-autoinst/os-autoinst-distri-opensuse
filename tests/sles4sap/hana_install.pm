# SUSE's SLES4SAP openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: lvm2 util-linux parted device-mapper
# Summary: Install HANA via command line. Verify installation with
# sles4sap/hana_test
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use utils qw(file_content_replace zypper_call);
use Utils::Systemd 'systemctl';
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

    my $lsblk = q@lsblk -n -l -o NAME -d -e 7,11 | grep -E -vw '@ . join('|', @pvdevs) . "'";
    # lsblk command to probe for devices is different when in multipath scenario
    $lsblk = q@lsblk -l -o NAME,TYPE -e 7,11 | awk '($2 == "mpath") {print $1}' | sort -u | grep -E -vw '@ . join('|', @pvdevs) . "'" if is_multipath();

    # Probe devices, check its size and filter out the ones that do not meet the disk requirements
    my $devsize = 0;
    my $devpath = is_multipath() ? '/dev/mapper/' : '/dev/';
    my $device;
    my $filter_devices;
    while ($devsize < $disk_requirement) {
        $out = script_output "echo DEV=\$($lsblk | grep -E -vw '$filter_devices' | head -1)";
        die "Could not find a suitable device for HANA installation." unless ($out =~ /DEV=([\w\.]+)$/);
        $device = $1;
        $filter_devices .= "|$device";
        $filter_devices =~ s/^\|//;
        $device = $devpath . $device;

        # Need to verify there is enough space in the device for HANA
        $out = script_output "echo SIZE=\$(lsblk -o SIZE --nodeps --noheadings --bytes $device)";
        die "Could not get size for [$device] block device." unless ($out =~ /SIZE=(\d+)$/);
        $devsize = $1;
        $devsize /= (1024 * 1024);    # Work in Mbytes since $RAM = $self->get_total_mem() is in Mbytes
    }

    return $device;
}

sub debug_locked_device {
    my ($self) = @_;
    for ('dmsetup info', 'dmsetup ls', 'mount', 'df -h', 'pvscan', 'vgscan', 'lvscan', 'pvdisplay', 'vgdisplay', 'lvdisplay') {
        my $filename = $_;
        $filename =~ s/[^\w]/_/g;
        $self->save_and_upload_log($_, "$filename.txt");
    }
}

sub get_test_summary {
    my ($self) = @_;
    my $info = "HANA Installation finished successfully.\n\nOS Details:\n\n";
    $info .= 'Product Code: ';
    $info .= script_output 'basename $(realpath /etc/products.d/baseproduct)';
    $info =~ s/.prod//;
    $info .= "\n";
    $info .= script_output 'grep -E ^VERSION= /etc/os-release';
    $info =~ s/VERSION=/Version: /;
    $info .= "\nProduct Name: ";
    $info .= script_output q(grep -w summary /etc/products.d/baseproduct | sed -r -e 's@<.?summary>@@g');
    $info .= "\n\nHANA Details:\n\n";
    $info .= script_output 'grep -E "INFO.*SAP HANA Lifecycle Management" /var/tmp/hdblcm.log | cut -d" " -f3,11-';
    return $info;
}

sub run {
    my ($self) = @_;
    my ($proto, $path) = $self->fix_path(get_required_var('HANA'));
    my $sid = get_required_var('INSTANCE_SID');
    my $instid = get_required_var('INSTANCE_ID');
    my $tout = get_var('HANA_INSTALLATION_TIMEOUT', 3600);    # Timeout for HANA installation commands.

    select_serial_terminal;
    my $RAM = $self->get_total_mem();
    die "RAM=$RAM. The SUT needs at least 24G of RAM" if $RAM < 24000;

    zypper_call('in SAPHanaSR SAPHanaSR-doc ClusterTools2') if get_var('HA_CLUSTER');

    # Add host's IP to /etc/hosts
    $self->add_hostname_to_hosts;

    # Install libopenssl1_0_0 for older (<SPS03) HANA versions on SLE15+
    $self->install_libopenssl_legacy($path);

    # This installs HANA. Start by configuring the appropiate SAP profile
    $self->prepare_profile('HANA');

    # Mount media
    $self->mount_media($proto, $path, '/sapinst');

    # Mount points information: use the same paths and minimum sizes as the wizard (based on RAM size)
    my $full_size = ceil($RAM / 1024);    # Use the ceil value of RAM in GB
    my $half_size = ceil($full_size / 2);
    my $volgroup = 'vg_hana';
    my %mountpts = (
        hanadata => {mountpt => '/hana/data', size => "${full_size}g"},
        hanalog => {mountpt => '/hana/log', size => "${half_size}g"},
        hanashared => {mountpt => '/hana/shared', size => "${full_size}g"},
        usr_sap => {mountpt => "/usr/sap/$sid/home", size => '50g'}
    );

    # Partition disks for Hana
    if (check_var('HANA_PARTITIONING_BY', 'yast')) {
        my $yast_partitioner = is_sle('15+') ? 'sap_create_storage_ng' : 'sap_create_storage';
        assert_script_run "yast $yast_partitioner /usr/share/YaST2/data/y2sap/hana_partitioning.xml", 120;
    }
    else {
        # If running on QEMU and with a second disk configured, then configure
        # mountpoints and LVM. Otherwise leave those choices to hdblcm. If running
        # in a different backend, assume sdb exists. Always create mountpoints.
        foreach (keys %mountpts) { assert_script_run "mkdir -p $mountpts{$_}->{mountpt}"; }
        if ((is_qemu and get_var('HDDSIZEGB_2')) or !is_qemu) {
            # We need 2.5 times $RAM + 50G for HANA installation.
            my $device = get_var('HANA_INST_DEV', '');
            if ($device) {
                die "Full path to block device expected in HANA_INST_DEV. Got [$device]" unless ($device =~ m|(/dev/\w+)(\d+)|);
                my $disk = $1;
                my $partnum = $2;
                if (script_run "test -b $device") {
                    # Need to create the partition if it does not exist
                    my $lastsector = script_output "parted --machine --script $disk -- unit MB print | tail -1 | cut -d: -f3";
                    $lastsector =~ /(\d+)MB/;
                    $lastsector = $1 + 1;
                    assert_script_run "parted --script $disk -- mkpart primary $lastsector -1";
                    assert_script_run "parted --script $disk -- set $partnum lvm on";
                    assert_script_run "test -b $device";    # Check partition was created successfully
                    script_run "wipefs -a -f $device";    # This is a new partition, but it could have traces of old tests. We do some cleanup
                    script_run "partprobe $device";    # Reload kernel table
                }
            }
            else {
                $device = $self->get_hana_device_from_system(($RAM * 2.5) + 50000);
                record_info "Device: $device", "Will use device [$device] for HANA installation";
                script_run "wipefs -f $device; [[ -b ${device}1 ]] && wipefs -f ${device}1; [[ -b ${device}-part1 ]] && wipefs -f ${device}-part1";
                assert_script_run "parted --script $device --wipesignatures -- mklabel gpt mkpart primary 1 -1";
                $device .= is_multipath() ? '-part1' : '1';
            }

            # Remove traces of LVM structures from previous tests before configuring
            foreach (keys %mountpts) { script_run "dmsetup remove $volgroup-lv_$_"; }
            foreach my $lv_cmd ('lv', 'vg', 'pv') {
                my $looptime = 20;
                my $lv_device = ($lv_cmd eq 'pv') ? $device : $volgroup;
                until (script_run "${lv_cmd}remove -f $lv_device 2>&1 | grep -q \"Can't open .* exclusively\.\"") {
                    sleep bmwqemu::scale_timeout(2);
                    # Try to fix device-mapper table as a workaround
                    script_run("dmsetup remove $lv_device");
                    last if (--$looptime <= 0);
                }
                if ($looptime <= 0) {
                    record_info('ERROR', "Device $lv_device seems to be locked!", result => 'fail');
                    # Retry the $lv_cmd one last time to have a "proper" error message, and run some debug commands
                    script_run "${lv_cmd}remove -f $lv_device";
                    $self->debug_locked_device;
                    die 'poo#96833 - locked block device';    # Device is locked. We cannot remove or create a PV there. Fail the test
                }
            }

            # Now configure LVs and file systems for HANA
            assert_script_run "pvcreate -y $device";
            assert_script_run "vgcreate -f $volgroup $device";
            foreach my $mounts (keys %mountpts) {
                assert_script_run "lvcreate -y -W y -n lv_$mounts --size $mountpts{$mounts}->{size} $volgroup";
                assert_script_run "mkfs.xfs -f /dev/$volgroup/lv_$mounts";
                assert_script_run "mount /dev/$volgroup/lv_$mounts $mountpts{$mounts}->{mountpt}";
                assert_script_run "echo /dev/$volgroup/lv_$mounts $mountpts{$mounts}->{mountpt} xfs defaults 0 0 >> /etc/fstab";
            }
        }
    }
    # Configure NVDIMM devices only when running on a BACKEND with NVDIMM
    my $pmempath = get_var('HANA_PMEM_BASEPATH', "/hana/pmem/$sid");
    if (get_var('NVDIMM')) {
        my $nvddevs = get_var('NVDIMM_NAMESPACES_TOTAL', 2);
        foreach my $i (0 .. ($nvddevs - 1)) {
            assert_script_run "mkdir -p $pmempath/pmem$i";
            assert_script_run "mkfs.xfs -f /dev/pmem$i";
            assert_script_run "echo /dev/pmem$i $pmempath/pmem$i xfs defaults,noauto,dax 0 0 >> /etc/fstab";
            assert_script_run "mount $pmempath/pmem$i";
        }

        assert_script_run 'mkdir -p /etc/systemd/system/systemd-udev-settle.service.d';
        assert_script_run "curl -f -v " . autoinst_url .
          '/data/sles4sap/udev-settle-override.conf -o /etc/systemd/system/systemd-udev-settle.service.d/00-override.conf';
        systemctl 'daemon-reload';
        systemctl 'restart systemd-udev-settle';

        assert_script_run "chmod 0777 $pmempath -R";
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
    push @hdblcm_args, "--pmempath=$pmempath", "--use_pmem" if get_var('NVDIMM');
    # NOTE: Remove when SAP releases HANA with a fix for bsc#1195133
    if (get_var('NVDIMM')) {
        push @hdblcm_args, "--ignore=check_signature_file";
        record_soft_failure("Workaround for bsc#1195133");
    }
    my $cmd = join(' ', $hdblcm, @hdblcm_args);
    record_info 'hdblcm command', $cmd;
    assert_script_run $cmd, $tout;

    # Enable autostart of HANA HDB, otherwise DB will be down after the next reboot
    # NOTE: not on HanaSR, as DB is managed by the cluster stack; nor on bare metal,
    # as instance starts automatically faster and sles4sap::test_start() may fail
    unless (get_var('HA_CLUSTER') or is_ipmi) {
        my $hostname = script_output 'hostname';
        file_content_replace("$mountpts{hanashared}->{mountpt}/${sid}/profile/${sid}_HDB${instid}_${hostname}", '^Autostart[[:blank:]]*=.*' => 'Autostart = 1');
    }

    if (get_var('NVDIMM')) {
        assert_script_run 'chown ' . lc($sid) . "adm:sapsys $pmempath $pmempath/pmem*";
        assert_script_run "chmod 0755 $pmempath $pmempath/pmem*";
    }

    # Upload installations logs
    $self->upload_hana_install_log;
    $self->save_and_upload_log('rpm -qa', 'packages.list');
    $self->save_and_upload_log('systemctl list-units --all', 'systemd-units.list');

    # Quick check of block/filesystem devices after installation
    assert_script_run 'mount';
    assert_script_run 'lvs -ao +devices';

    # Test summary
    record_info 'Test Summary', $self->get_test_summary;
}

sub test_flags {
    return {fatal => 1};
}

1;

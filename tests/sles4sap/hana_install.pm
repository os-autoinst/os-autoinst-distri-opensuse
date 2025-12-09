# SUSE's SLES4SAP openQA tests
#
# Copyright 2019-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: lvm2 util-linux parted device-mapper
# Summary: Install HANA via command line. Verify installation with
# sles4sap/hana_test
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use utils qw(file_content_replace zypper_call);
use Utils::Systemd 'systemctl';
use version_utils qw(is_sle has_selinux);
use POSIX 'ceil';
use Utils::Logging 'save_and_upload_log';
use repo_tools 'add_qa_head_repo';

sub is_multipath {
    return (get_var('MULTIPATH') and (get_var('MULTIPATH_CONFIRM') !~ /\bNO\b/i));
}

sub get_hana_device_from_system {
    my ($self, $disk_requirement) = @_;

    # Create a list of devices already configured as PVs to exclude them from the search
    my $out = script_output q@echo PV=$(pvscan -s 2>/dev/null | awk '/dev/ {print $1}' | tr '\n' ',')@;
    $out =~ /PV=(.+),$/;
    $out = $1;
    my @pvdevs = map {
        if ($_ =~ s@mapper/@@) { $_ =~ s/\-part\d+$// }
        else { $_ =~ s/\d+$// }
        $_ =~ s@^/dev/@@;
        $_;
    } split(/,/, $out);

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
        save_and_upload_log($_, "$filename.txt");
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

sub restorecon_rootfs {
    # restorecon does not behave too well with btrfs, so exclude /.snapshots in btrfs rootfs
    my $restorecon_cmd = 'restorecon -i -R /';
    $restorecon_cmd .= ' -e /.snapshots' unless (script_run('test -d /.snapshots'));
    assert_script_run "$restorecon_cmd";
}

sub run {
    my ($self) = @_;
    my ($proto, $path) = $self->fix_path(get_required_var('HANA'));
    my $sid = get_required_var('INSTANCE_SID');
    my $instid = get_required_var('INSTANCE_ID');
    # set timeout as 4800 as a temp workaround for slow nfs
    my $tout = get_var('HANA_INSTALLATION_TIMEOUT', 4800);    # Timeout for HANA installation commands.

    select_serial_terminal;
    my $RAM = $self->get_total_mem();
    die "RAM=$RAM. The SUT needs at least 24G of RAM" if $RAM < 24000;

    if (get_var('HA_CLUSTER')) {
        my @zypper_in = ('install');
        # Check for SAPHanaSR-angi package going to be used
        if (get_var('USE_SAP_HANA_SR_ANGI')) {
            foreach ('SAPHanaSR-doc', 'SAPHanaSR') {
                assert_script_run("rpm -e --nodeps $_") if (script_run("rpm -q $_") == 0);
            }
            push @zypper_in, 'SAPHanaSR-angi', 'supportutils-plugin-ha-sap';
        }
        else {
            push @zypper_in, 'SAPHanaSR', 'SAPHanaSR-doc';
        }
        zypper_call(join(' ', @zypper_in));
    }

    # Workaround for SLE16 if variable WORKAROUND_BSC1234806 set
    if (get_var("WORKAROUND_BSC1234806")) {
        record_soft_failure("bsc#1234806: workaround by installing hana_insserv_compat package from QA:HEAD");
        add_qa_head_repo;
        zypper_call("in hana_insserv_compat");
    }

    # Modify SELinux mode
    if (get_var("WORKAROUND_BSC1239148")) {
        record_soft_failure("bsc#1239148: workaround by changing mode to Permissive");
        $self->modify_selinux_setenforce('selinux_mode' => 'Permissive');
    }

    # On SLES for SAP 16.0 and newer, we need to do further SELinux setup for HANA
    if (has_selinux) {
        assert_script_run 'semanage boolean -m --on selinuxuser_execmod';
        assert_script_run 'semanage boolean -m --on unconfined_service_transition_to_unconfined_user';
        assert_script_run 'semanage permissive -a snapper_grub_plugin_t';
        restorecon_rootfs();
    }

    # Add host's IP to /etc/hosts
    $self->add_hostname_to_hosts;

    # Install libopenssl1_0_0 for older (<SPS03) HANA versions on SLE15+
    $self->install_libopenssl_legacy($path);

    # This installs HANA. Start by configuring the appropiate SAP profile
    $self->prepare_profile('HANA');

    # Transfer media.
    my $target = '/sapinst';    # Directory in SUT where install media will be copied token
    if (get_var 'ASSET_0') {
        # If the ASSET_0 variable is defined, the test will attempt to download
        # the HANA media from the factory/other directory of the openQA server.
        record_info "Dowloading using ASSET_0";
        $self->download_hana_assets_from_server(target => $target, nettout => $tout);
    }
    elsif (get_required_var 'HANA') {
        # If not, the media will be retrieved from a remote server.
        record_info "Downloading using $proto";
        $self->copy_media($proto, $path, $tout, $target);
    }
    # Mount points information: use the same paths and minimum sizes as the wizard (based on RAM size)
    my $full_size = ceil($RAM / 1024);    # Use the ceil value of RAM in GB
    my $half_size = ceil($full_size / 2);
    my $volgroup = 'vg_hana';
    my %mountpts = (
        hanadata => {mountpt => '/hana/data', size => "${full_size}g"},
        hanalog => {mountpt => '/hana/log', size => "${half_size}g"},
        hanashared => {mountpt => '/hana/shared', size => "${full_size}g"},
        usr_sap => {mountpt => "/usr/sap/$sid/home", size => '50g'});

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
        # Read all configured pmem devices on the system
        my @pmem_devices_all = split("\n", script_output("find /dev/pmem*"));
        foreach my $pmem_device (@pmem_devices_all) {
            $pmem_device =~ s:/dev/(pmem\S+).*:$1:;
            assert_script_run "mkdir -p $pmempath/$pmem_device";
            assert_script_run "mkfs.xfs -f /dev/$pmem_device";
            assert_script_run "echo /dev/$pmem_device $pmempath/$pmem_device xfs defaults,noauto,dax 0 0 >> /etc/fstab";
            assert_script_run "mount $pmempath/$pmem_device";
        }

        assert_script_run 'mkdir -p /etc/systemd/system/systemd-udev-settle.service.d';
        assert_script_run "curl -f -v "
          . autoinst_url
          . '/data/sles4sap/udev-settle-override.conf -o /etc/systemd/system/systemd-udev-settle.service.d/00-override.conf';
        systemctl 'daemon-reload';
        systemctl 'restart systemd-udev-settle';

        assert_script_run "chmod 0777 $pmempath -R";
    }
    assert_script_run "df -h";

    # Run restorecon again on SLES for SAP 16.0 and newer as we have created and mounted new
    # FS since the last run
    restorecon_rootfs() if has_selinux;

    # hdblcm is used for installation, verify if it exists.
    # hdblcm can be provided from the external with HANA_HDBLCM
    # variable, that is a relative path to /sapinst
    my $hdblcm = join('/', $target,
        get_var(
            'HANA_HDBLCM',
            "DATA_UNITS/HDB_SERVER_LINUX_" . uc(get_required_var('ARCH')) . '/hdblcm'));
    die "hdblcm is not in [$hdblcm]. Set HANA_HDBLCM to the appropiate relative path. Example: DATA_UNITS/HDB_SERVER_LINUX_X86_64/hdblcm"
      if (script_run "ls $hdblcm");

    # Install hana: Prepare hdblcm args.
    # Note: set "--components=server,client" as other test moudle (monitoring_services.pm)
    # installs shared pkgs from dir 'hdbclient'
    my @hdblcm_args = qw(--autostart=n --shell=/bin/sh --workergroup=default --system_usage=custom --batch
      --hostname=$(hostname) --db_mode=multiple_containers --db_isolation=low --restrict_max_mem=n
      --groupid=79 --use_master_password=n --skip_hostagent_calls=n --system_usage=production
    );
    push @hdblcm_args, "--userid=" . get_var('SIDADM_UID', '1001');
    push @hdblcm_args,
      "--components=" . get_var("HDBLCM_COMPONENTS", 'server'),
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
    push @hdblcm_args, "--component_dirs=$target/" . get_var('HDB_CLIENT_LINUX') if get_var('HDB_CLIENT_LINUX');
    push @hdblcm_args, get_var('HDBLCM_EXTRA_ARGS') if get_var('HDBLCM_EXTRA_ARGS');

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
    save_and_upload_log('rpm -qa', 'packages.list');
    save_and_upload_log('systemctl list-units --all', 'systemd-units.list');

    # On SLES for SAP 16.0 and newer, we need to do further SELinux setup for HANA
    restorecon_rootfs() if has_selinux;

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

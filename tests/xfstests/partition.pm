# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: parted
# Summary: Create partitions for xfstests
# - Create a gpt partition table on device
# - Partition device according to system variable XFSTESTS_DEVICE or
# calculated home size
# Maintainer: Yong Sun <yosun@suse.com>
package partition;

use 5.018;
use Mojo::Base 'opensusebasetest';
use utils;
use testapi;
use serial_terminal 'select_serial_terminal';
use filesystem_utils qw(str_to_mb parted_print partition_num_by_type mountpoint_to_partition
  partition_table create_partition remove_partition format_partition get_partition_size);
use File::Basename;
use lockapi;
use mmapi;
use mm_network;
use nfs_common;
use Utils::Systemd 'disable_and_stop_service';
use registration;
use version_utils qw(is_transactional is_sle_micro is_sle);
use Utils::Architectures 'is_ppc64le';
use transactional;
use Kernel::block_dev qw(create_loop_backing_file attach_loop_device);
use Kernel::nfs qw(setup_pnfs_client verify_pnfs_block_layout);
use List::Util 'sum';
use rdma;

my $INST_DIR = '/opt/xfstests';
my $CONFIG_FILE = "$INST_DIR/local.config";
my $NFS_VERSION = get_var('XFSTESTS_NFS_VERSION', '4.1');
my $NFS_SERVER_IP;
my $TEST_FOLDER = '/opt/test';
my $SCRATCH_FOLDER = '/opt/scratch';

# Consolidated device setup coordinator for xfstests.
# Expected %para input contract:
#   mode:    'partition' | 'loop' | 'zoned' | 'nfs' (mandatory, defines the storage medium workflow)
#   fstype:  target filesystem (e.g., 'btrfs', 'xfs', 'overlay', 'nfs', used in all modes)
#   size:    total capacity (only used in 'partition' and 'loop' modes, requires unit suffixes like '50G' or '51200M', parsed via str_to_mb)
#   dev:     target physical disk to partition (e.g., '/dev/vda', only used in 'partition' mode, optional)
#   delhome: boolean, deletes the /home partition to free space (only used in 'partition' mode, optional)
sub setup_xfstests_devices {
    my $ref = shift;
    my %para = %{$ref};
    my $mode = $para{mode};
    my $fstype = $para{fstype};

    my ($test_dev, @scratch_devs, @dev_sizes, $logdev);
    my $is_overlay = ($fstype =~ /overlay/) ? 1 : 0;

    # ==================== Stage 1: Device Creation ====================
    if ($mode eq 'zoned') {
        my $ZONE_CREATER = '/opt/nullblk-zoned.sh';
        assert_script_run("curl -o $ZONE_CREATER " . data_url('xfstests/nullblk-zoned.sh'));
        assert_script_run("chmod a+x $ZONE_CREATER");
        script_run("for i in {1..6}; do $ZONE_CREATER 4096 256 4 16; done");

        $test_dev = '/dev/nullb0';
        @scratch_devs = map { "/dev/nullb$_" } (1 .. 5);
        @dev_sizes = ('5120M') x 6;
        assert_script_run("mkfs.btrfs -f $test_dev");
    }
    elsif ($mode eq 'nfs') {
        # NFS Client Mode: No local block devices to provision.
        # Test targets are the remote NFS server exports.
        $test_dev = "$NFS_SERVER_IP:/opt/export/test";
        @scratch_devs = ("$NFS_SERVER_IP:/opt/export/scratch");
        @dev_sizes = ('0M') x 2;
    }
    else {
        my $amount = ($fstype =~ /btrfs/) ? 5 : 1;
        my $total_mb = $para{size};
        my ($dev, $part_type, $test_path, @scratch_paths);

        # Sizing and margins (normalize size to MB first)
        $total_mb = str_to_mb($total_mb);
        $total_mb = ($mode eq 'loop') ? int($total_mb * 0.9) : $total_mb - ($total_mb > 100 ? 100 : 0);

        # Space Allocation
        my @sizes;
        if (my @part_list = split(/,/, get_var('XFSTESTS_PART_SIZE'))) {
            my $list_remaining = $amount + 1 - (scalar @part_list);
            if ($list_remaining > 0) {
                my $sum_parts = sum @part_list;
                my $remaining_space = $total_mb - $sum_parts;
                my $pad_size = $remaining_space > 0 ? int($remaining_space / $list_remaining) : 0;
                push(@part_list, ($pad_size) x $list_remaining);
            }
            @sizes = @part_list[0 .. $amount];
        } else {
            my $single_size = int($total_mb / ($amount + 1));
            $single_size = 20480 if $single_size > 20480;
            @sizes = ($single_size) x ($amount + 1);
        }
        @dev_sizes = map { $_ . 'M' } @sizes;

        # Media Creation
        if ($mode eq 'loop') {
            my @filename = ('test_dev', map { "scratch_dev$_" } (1 .. $amount));
            for my $i (0 .. $#filename) {
                create_loop_backing_file("$INST_DIR/$filename[$i]", $dev_sizes[$i]);
                attach_loop_device("$INST_DIR/$filename[$i]");
            }
            script_run("losetup -a");

            $test_dev = '/dev/loop0';
            @scratch_devs = map { "/dev/loop$_" } (1 .. $amount);

            # Loop Mode: SUT mounts loop block devices (/dev/loopX), but standard mkfs formatting
            # should operate directly on the raw backing files (e.g. /opt/xfstests/test_dev)
            ($test_path, @scratch_paths) = map { "$INST_DIR/$_" } @filename;
        }
        else {
            unless (exists($para{dev})) {
                my $part = mountpoint_to_partition('/');
                $para{dev} = $1 if $part =~ /(.*?)(\d+)/;
            }
            $dev = $para{dev};

            if ($para{delhome}) {
                remove_partition(mountpoint_to_partition('/home'));
                script_run("sed -i -e '/ \/home /d' /etc/fstab");
                script_run('mkdir -p /home/fsgqa /home/fsgqa-123456');
            }

            parted_print(dev => $dev);
            my $part_table = partition_table($dev);
            $part_type = ($part_table =~ 'msdos') ? 'logical' : 'primary';

            if ($part_table =~ 'msdos' && partition_num_by_type($dev, 'extended') == -1) {
                create_partition($dev, 'extended', 'max');
                parted_print(dev => $dev);
            }

            $test_dev = create_partition($dev, $part_type, shift @sizes);
            parted_print(dev => $dev);
            @scratch_devs = map { create_partition($dev, $part_type, $_) } @sizes;
            parted_print(dev => $dev);

            # Physical Partition Mode: Format targets are identical to the partition block devices.
            ($test_path, @scratch_paths) = ($test_dev, @scratch_devs);
        }

        # ==================== Stage 2: Formatting ====================
        my $effective_fstype = $fstype;
        if ($fstype =~ /overlay|nfs/) {
            my $base_fs = get_var('XFSTESTS_OVERLAY_BASE_FS', 'xfs');
            format_with_options($test_path, $base_fs);
            format_with_options($scratch_paths[0], $base_fs);
            return @dev_sizes if $mode eq 'loop' && $fstype =~ /nfs/;
            script_run("echo 'export FSTYP=$base_fs' >> $CONFIG_FILE") if $fstype =~ /overlay/;
            $effective_fstype = $base_fs;
        } else {
            format_with_options($test_path, $fstype);
        }

        # Create External Log Device (if requested)
        if (get_var('XFSTESTS_LOGDEV')) {
            if ($mode eq 'loop') {
                $logdev = "/dev/loop100";
                create_loop_backing_file("$INST_DIR/logdev", '1G');
                attach_loop_device("$INST_DIR/logdev", loop_dev => $logdev);
                format_partition("$INST_DIR/logdev", $fstype);
            } else {
                $logdev = create_partition($dev, $part_type, 1024);
                format_partition($logdev, $fstype);
            }
        }
        $fstype = $effective_fstype;
    }

    # ==================== Stage 3: Export Configurations ====================
    if (!get_var('XFSTESTS_NFS_SERVER')) {
        script_run("mkdir -p $TEST_FOLDER $SCRATCH_FOLDER");

        # 1. Global Debugging & Diagnostic Configurations
        script_run("echo export KEEP_DMESG=yes >> $CONFIG_FILE");
        if (get_var('XFSTESTS_XFS_REPAIR')) {
            script_run("echo export TEST_XFS_REPAIR_REBUILD=1 >> $CONFIG_FILE");
        }
        script_run("echo 'export DUMP_CORRUPT_FS=1' >> $CONFIG_FILE");
        script_run("echo 'export DUMP_COMPRESSOR=gzip' >> $CONFIG_FILE") if (script_run('which gzip') == 0);

        # 2. NFS Client Configurations
        if ($mode eq 'nfs') {
            script_run("echo export TEST_DEV=$test_dev >> $CONFIG_FILE");
            script_run("echo export TEST_DIR=/opt/nfs/test >> $CONFIG_FILE");
            script_run("echo export SCRATCH_DEV=$scratch_devs[0] >> $CONFIG_FILE");
            script_run("echo export SCRATCH_MNT=/opt/nfs/scratch >> $CONFIG_FILE");
            script_run("echo export FSTYP=nfs >> $CONFIG_FILE");
            if ($NFS_VERSION =~ 'pnfs') {
                script_run("echo export NFS_MOUNT_OPTIONS='\"-o rw,relatime,vers=4.1,minorversion=1\"' >> $CONFIG_FILE");
            }
            elsif ($NFS_VERSION =~ 'TLS') {
                script_run('modprobe tls');
                my ($vers_num) = $NFS_VERSION =~ /-([\d.]+)/;
                script_run("echo export NFS_MOUNT_OPTIONS='\"-o rw,relatime,vers=$vers_num,sec=sys,xprtsec=mtls\"' >> $CONFIG_FILE");
            }
            elsif ($NFS_VERSION =~ 'krb5') {
                my ($vers_num) = $NFS_VERSION =~ /-([\d.]+)/;
                my ($krb5_type) = $NFS_VERSION =~ /(krb5[pi]?)/;
                script_run("echo export NFS_MOUNT_OPTIONS='\"-o rw,relatime,vers=$vers_num,sec=$krb5_type\"' >> $CONFIG_FILE");
            }
            else {
                script_run("echo export NFS_MOUNT_OPTIONS='\"-o rw,relatime,vers=$NFS_VERSION\"' >> $CONFIG_FILE");
            }
        }
        # 3. Standard Block Device Configurations
        else {
            script_run("echo 'export FSTYP=$fstype' >> $CONFIG_FILE") unless $is_overlay;
            script_run("echo 'export TEST_DEV=$test_dev' >> $CONFIG_FILE");
            set_var('XFSTESTS_TEST_DEV', $test_dev);
            script_run("echo 'export TEST_DIR=$TEST_FOLDER' >> $CONFIG_FILE");
            script_run("echo 'export SCRATCH_MNT=$SCRATCH_FOLDER' >> $CONFIG_FILE");

            if (scalar @scratch_devs == 1) {
                script_run("echo 'export SCRATCH_DEV=$scratch_devs[0]' >> $CONFIG_FILE");
                set_var('XFSTESTS_SCRATCH_DEV', $scratch_devs[0]);
            } else {
                my $pool = join(' ', @scratch_devs);
                script_run("echo 'export SCRATCH_DEV_POOL=\"$pool\"' >> $CONFIG_FILE");
                set_var('XFSTESTS_SCRATCH_DEV_POOL', $pool);
            }

            if ($logdev) {
                script_run("echo export SCRATCH_LOGDEV=$logdev >> $CONFIG_FILE");
                script_run("echo export USE_EXTERNAL=yes >> $CONFIG_FILE");
            }
        }

        script_run('sync');
        record_info('Config file', script_output("cat $CONFIG_FILE"));
    }

    return @dev_sizes;
}

sub post_env_info {
    my @size = @_;
    # record version info
    my $ver_log = get_var('VERSION_LOG', '/opt/version.log');
    record_info('Version', script_output("cat $ver_log"));
    record_info('Kernel config', script_output('cat /boot/config-$(uname -r)'));

    # record partition size info
    my $size_info = get_var('XFSTESTS_TEST_DEV') . "    " . shift(@size) . "\n";
    if (my $scratch_dev = get_var("XFSTESTS_SCRATCH_DEV")) {
        $size_info = $size_info . "$scratch_dev    " . shift(@size) . "\n";
    }
    else {
        my @scratch_dev_pool = split(/ /, get_var("XFSTESTS_SCRATCH_DEV_POOL"));
        foreach (@scratch_dev_pool) {
            $size_info = $size_info . "$_    " . shift(@size) . "\n";
        }
    }
    $size_info = $size_info . "PAGE_SIZE     " . script_output("getconf PAGE_SIZE") . "\n";
    $size_info = $size_info . "QEMURAM       " . get_var("QEMURAM") . "\n";
    $size_info = $size_info . "\n" . script_output("df -h");
    record_info('Size', $size_info);

    # record mounted filesystem info
    my $mount_info = script_output("mount");
    record_info('Mount', $mount_info);
}

sub format_with_options {
    my ($part, $filesystem) = @_;
    # In case to test different mkfs.xfs options
    if ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'reflink_1024') != -1) {
        format_partition($part, $filesystem, options => '-f -m reflink=1,rmapbt=1, -i sparse=1, -b size=1024');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m reflink=1,rmapbt=1, -i sparse=1, -b size=1024\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'reflink_normapbt') != -1) {
        format_partition($part, $filesystem, options => '-f -m reflink=1,rmapbt=0, -i sparse=1');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m reflink=1,rmapbt=0, -i sparse=1\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'reflink') != -1) {
        format_partition($part, $filesystem, options => '-f -m reflink=1,rmapbt=1, -i sparse=1');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m reflink=1,rmapbt=1, -i sparse=1\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'nocrc_512') != -1) {
        format_partition($part, $filesystem, options => '-f -m crc=0,reflink=0,rmapbt=0, -i sparse=0, -b size=512');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m crc=0,reflink=0,rmapbt=0, -i sparse=0, -b size=512\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'nocrc') != -1) {
        format_partition($part, $filesystem, options => '-f -m crc=0,reflink=0,rmapbt=0, -i sparse=0');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m crc=0,reflink=0,rmapbt=0, -i sparse=0\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'logdev') != -1) {
        format_partition($part, 'xfs', options => '-f -m crc=1,reflink=0,rmapbt=0, -i sparse=0 -lsize=100m');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m crc=1,reflink=0,rmapbt=0, -i sparse=0 -lsize=100m\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'bigtime') != -1) {
        format_partition($part, 'xfs', options => '-f -m bigtime=1');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m bigtime=1\"' >> $CONFIG_FILE");
    }
    # In case to test different mkfs.btrfs options
    # $XFSTEST_MKFS_OPTION: options for mkfs.btrfs
    # Example of 4k block size: -f -s 4k -n 16k
    elsif ($filesystem eq 'btrfs' && (my $mkfs_option = get_var('XFSTEST_MKFS_OPTION'))) {
        format_partition($part, 'btrfs', options => "$mkfs_option");
        script_run("echo 'export BTRFS_MKFS_OPTIONS=\"$mkfs_option\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'ocfs2') {
        format_partition($part, 'ocfs2', options => '--fs-features=local --fs-feature-level=max-features');
        script_run("echo 'export MKFS_OPTIONS=\"--fs-features=local --fs-feature-level=max-features\"' >> $CONFIG_FILE");
    }
    else {
        format_partition($part, $filesystem);
    }
}

sub install_dependencies_ocfs2 {
    my $scc_product = get_var('VERSION') =~ s/-SP/./r;
    my $scc_arch = get_var('ARCH');
    my $scc_regcode = get_var('SCC_REGCODE_HA');
    add_suseconnect_product('sle-ha', $scc_product, $scc_arch, "-r $scc_regcode");
    my @deps = qw(
      ocfs2-tools
    );
    script_run('zypper --gpg-auto-import-keys ref');
    if (is_transactional) {
        trup_install(join(' ', @deps));
        reboot_on_changes;
    }
    else {
        zypper_call('in ' . join(' ', @deps));
    }
    script_run('modprobe ocfs2');
}

sub install_dependencies_nfs {
    my @deps = qw(
      nfs-kernel-server
      nfs4-acl-tools
    );
    push @deps, 'ktls-utils', 'openssl-3' if ($NFS_VERSION =~ 'TLS');
    push @deps, 'krb5-client', 'krb5-server' if ($NFS_VERSION =~ 'krb5');
    script_run('zypper --gpg-auto-import-keys ref');
    if (is_transactional) {
        trup_install(join(' ', @deps));
        reboot_on_changes;
    }
    else {
        zypper_call('in nfs-client ' . join(' ', @deps));
    }
}

sub install_dependencies_overlayfs {
    my @deps = qw(
      overlayfs-tools
      unionmount-testsuite
      libcap-progs
    );
    script_run('zypper --gpg-auto-import-keys ref');
    if (is_transactional) {
        # Excluding libcap-progs since install issue
        trup_install(join(' ', @deps[0 .. $#deps - 1]));
        reboot_on_changes;
    }
    else {
        zypper_call('in ' . join(' ', @deps));
    }
}

sub setup_ktls {
    my $tlshd_dir = '/etc/tlshd';
    assert_script_run("mkdir $tlshd_dir; cd $tlshd_dir");
    #Generate CA
    assert_script_run("openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ca.key -out ca.pem -subj \"/CN=NFS Test CA\"");
    #Generate server-CA
    assert_script_run("openssl req -new -nodes -newkey rsa:2048 -keyout server.key -out server.csr  -subj \"/CN=nfs-server\" -addext \"subjectAltName=IP:127.0.0.1,IP:0:0:0:0:0:0:0:1\"");
    assert_script_run("openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out server.pem -days 365 -extfile <(printf \"subjectAltName=IP:127.0.0.1,IP:0:0:0:0:0:0:0:1\")");
    #Generate client-CA(use for mtls, multi-way tls verification)
    assert_script_run("openssl req -new -nodes -newkey rsa:2048 -keyout client.key -out client.csr -subj \"/CN=nfs-client\" -addext \"subjectAltName=IP:127.0.0.1,IP:0:0:0:0:0:0:0:1\"");
    assert_script_run("openssl x509 -req -in client.csr -CA ca.pem -CAkey ca.key -CAcreateserial -out client.pem -days 365 -extfile <(printf \"subjectAltName=IP:127.0.0.1,IP:0:0:0:0:0:0:0:1\")");
    script_run('cd -');
    my $content = <<END;
[debug]
loglevel=1
tls=1
nl=1

[authenticate.client]
x509.truststore = /etc/tlshd/ca.pem
x509.certificate = /etc/tlshd/client.pem
x509.private_key = /etc/tlshd/client.key

[authenticate.server]
x509.truststore = /etc/tlshd/ca.pem
x509.certificate = /etc/tlshd/server.pem
x509.private_key = /etc/tlshd/server.key
END
    write_sut_file('/etc/tlshd.conf', $content);
    script_run("sed -i '/^ExecStart/ s|ExecStart=.*|ExecStart=/usr/sbin/tlshd -c /etc/tlshd.conf|' /usr/lib/systemd/system/tlshd.service");
    script_run('systemctl daemon-reload; systemctl enable tlshd.service; systemctl start tlshd.service');
}

sub setup_krb5 {
    script_run('hostname localhost');
    script_run('echo "127.0.0.1 localhost localhost.localdomain" >> /etc/hosts');
    my $content = <<END;
includedir  /etc/krb5.conf.d

[libdefaults]
    dns_canonicalize_hostname = false
    rdns = false
    verify_ap_req_nofail = true
    default_ccache_name = KEYRING:persistent:%{uid}
    default_realm = SUSETEST.COM
    dns_lookup_realm = false
    dns_lookup_kdc = false

[realms]
       SUSETEST.COM = {
        kdc = 127.0.0.1:88
        admin_server = 127.0.0.1:749
    }

[logging]
    kdc = FILE:/var/log/krb5/krb5kdc.log
    admin_server = FILE:/var/log/krb5/kadmind.log
    default = SYSLOG:NOTICE:DAEMON
END
    write_sut_file('/etc/krb5.conf', $content);

    #Config idmapd.conf
    $content = <<END;
[General]
Domain = susetest.com

[Mapping]
Nobody-User = nobody
Nobody-Group = nobody
END
    write_sut_file('/etc/idmapd.conf', $content);

    #create KDC database, start service and setup key
    script_run('kdb5_util create -s -P susetest -r SUSETEST.COM');
    script_run('systemctl start krb5kdc kadmind; systemctl enable krb5kdc kadmind');
    script_run('echo -e "susetest\nsusetest" | kadmin.local -q "addprinc root/admin@SUSETEST.COM"');
    script_run('kadmin.local -q "addprinc -randkey nfs/localhost@SUSETEST.COM"');
    script_run('kadmin.local -q "ktadd -k /etc/krb5.keytab nfs/localhost@SUSETEST.COM"');

    #create fsgqa/fsgqa2 users for some xfstests
    script_run('kadmin.local -q "addprinc -randkey fsgqa@SUSETEST.COM"');
    script_run('kadmin.local -q "addprinc -randkey fsgqa2@SUSETEST.COM"');
    script_run('kadmin.local -q "ktadd -k /etc/krb5.keytab fsgqa@SUSETEST.COM"');
    script_run('kadmin.local -q "ktadd -k /etc/krb5.keytab fsgqa2@SUSETEST.COM"');

    #verify the key
    script_run('klist -kte /etc/krb5.keytab');
    script_run('kadmin.local -q "getprinc nfs/localhost@SUSETEST.COM"');

    #get kerberos ticket and check
    script_run('kinit -k host/localhost@SUSETEST.COM');
    script_run('klist');
    script_run('kinit -k nfs/localhost@SUSETEST.COM');
    script_run('klist');

    script_run("systemctl restart nfs-idmapd");
    script_run("systemctl restart rpc-gssd");
    script_run("sleep 10");
}

sub setup_nfs_server {
    my $nfsversion = shift;
    if ($nfsversion =~ 'TLS') {
        setup_ktls;
    }
    if ($nfsversion =~ 'pnfs') {
        my %para;
        $para{fstype} = 'nfs';
        $para{size} = str_to_mb(script_output("df -h | grep /\$ | awk -F \" \" \'{print \$4}\'"));
        create_loop_device_by_rootsize(\%para);
        assert_script_run('mkdir -p /opt/export/test /opt/export/scratch /opt/nfs/test /opt/nfs/scratch && mount /dev/loop0 /opt/export/test && mount /dev/loop1 /opt/export/scratch && chown nobody:nogroup /opt/export/test /opt/export/scratch && echo \'/opt/export/test *(rw,pnfs,no_subtree_check,no_root_squash,fsid=1)\' >> /etc/exports && echo \'/opt/export/scratch *(rw,pnfs,no_subtree_check,no_root_squash,fsid=2)\' >> /etc/exports');
        record_info('pNFS export dev', script_output('df -Th /opt/export/test /opt/export/scratch', proceed_on_failure => 1));
    }
    elsif ($nfsversion =~ 'krb5') {
        setup_krb5($nfsversion);
        assert_script_run('mkdir -p /opt/export/test /opt/export/scratch /opt/nfs/test /opt/nfs/scratch && chown nobody:nogroup /opt/export/test /opt/export/scratch && echo \'/opt/export/test *(rw,no_subtree_check,no_root_squash,sec=krb5:krb5i:krb5p,fsid=1)\' >> /etc/exports && echo \'/opt/export/scratch *(rw,no_subtree_check,no_root_squash,sec=krb5:krb5i:krb5p,fsid=2)\' >> /etc/exports');
        script_run("sed -i 's/RPCGSSDARGS=\"/RPCGSSDARGS=\"-vvv /' /etc/sysconfig/nfs");
        script_run("systemctl daemon-reload");
    }
    else {
        assert_script_run('mkdir -p /opt/export/test /opt/export/scratch /opt/nfs/test /opt/nfs/scratch && chown nobody:nogroup /opt/export/test /opt/export/scratch && echo \'/opt/export/test *(rw,no_subtree_check,no_root_squash,fsid=1)\' >> /etc/exports && echo \'/opt/export/scratch *(rw,no_subtree_check,no_root_squash,fsid=2)\' >> /etc/exports');
    }
    my $nfsgrace = get_var('NFS_GRACE_TIME', 15);
    assert_script_run("echo 'options lockd nlm_grace_period=$nfsgrace' >> /etc/modprobe.d/lockd.conf && echo 'options lockd nlm_timeout=5' >> /etc/modprobe.d/lockd.conf");

    if ($nfsversion =~ '3') {
        assert_script_run("echo 'MOUNT_NFS_V3=\"yes\"' >> /etc/sysconfig/nfs");
        assert_script_run("echo 'MOUNT_NFS_DEFAULT_PROTOCOL=3' >> /etc/sysconfig/autofs && echo 'OPTIONS=\"-O vers=3\"' >> /etc/sysconfig/autofs");
        assert_script_run("echo '[NFSMount_Global_Options]' >> /etc/nfsmount.conf && echo 'Defaultvers=3' >> /etc/nfsmount.conf && echo 'Nfsvers=3' >> /etc/nfsmount.conf");
        record_info('nfsmount.conf file', script_output("cat /etc/nfsmount.conf"));
    }
    else {
        assert_script_run("sed -i 's/NFSV4LEASETIME=\"\"/NFSV4LEASETIME=\"$nfsgrace\"/' /etc/sysconfig/nfs");
        my $content = <<END;
[nfsd]
grace-time=$nfsgrace
lease-time=$nfsgrace
END
        write_sut_file('/etc/nfs.conf', $content);
        if ($nfsversion =~ 'pnfs') {
            assert_script_run("echo '[NFSMount_Global_Options]' >> /etc/nfsmount.conf && echo 'Defaultvers=4.1' >> /etc/nfsmount.conf && echo 'Nfsvers=4.1' >> /etc/nfsmount.conf");
        }
        enable_rdma_in_nfs if $nfsversion =~ 'rdma';
    }
    assert_script_run('exportfs -a && systemctl restart rpcbind && systemctl enable nfs-server.service && systemctl restart nfs-server');
}

sub setup_nfs_client {
    my $nfsversion = shift;
    setup_pnfs_client if ($nfsversion =~ 'pnfs');
    if ($nfsversion =~ 'rdma') {
        install_rdma_dependency;
        modprobe_rdma;
        link_add_rxe;
        rdma_record_info;
    }
    if ($nfsversion =~ 'rdma') {
        my $ip_addr = script_output("ip route | awk 'NR==2 {print \$9}'");
        script_run("mount -t nfs4 -o vers=4.1,minorversion=1,rdma $ip_addr:/opt/export/test /opt/nfs/test");
        record_info('pNFS_checkpoint', script_output('cat /proc/self/mountstats | grep pnfs', proceed_on_failure => 1));
        record_info('rdma mount checkpoint', script_output('cat /proc/fs/nfsfs/servers; grep opts: /proc/self/mountstats; grep xprt: /proc/self/mountstats', proceed_on_failure => 1));
    }
    elsif ($nfsversion =~ 'pnfs') {
        script_run('mount -t nfs4 -o vers=4.1,minorversion=1 localhost:/opt/export/test /opt/nfs/test');
        record_info('pNFS_checkpoint', script_output('cat /proc/self/mountstats | grep pnfs', proceed_on_failure => 1));
        record_info('/etc/exports', script_output('cat /etc/exports', proceed_on_failure => 1));
        record_info('nfsstat -m', script_output('nfsstat -m', proceed_on_failure => 1));
        script_run('umount /opt/nfs/test');
    }
    # There's a graceful time we need to wait before using the NFS server
    my $gracetime = script_output('cat /proc/fs/nfsd/nfsv4gracetime;');
    sleep($gracetime * 2);
    if ($nfsversion =~ 'pnfs' && get_var('XFSTESTS_PNFS_TRAFFIC_CHECK')) {
        verify_pnfs_block_layout('localhost', '/opt/export/test', '/opt/nfs/test', '/dev/loop0');
    }
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # DO NOT set XFSTESTS_DEVICE if you don't know what's this mean
    # by default we use /home partition spaces for test, and don't need this setting
    my $device = get_var('XFSTESTS_DEVICE');
    my $loopdev = get_var('XFSTESTS_LOOP_DEVICE');
    my $zonedev = get_var('XFSTESTS_ZONE_DEVICE');

    my $filesystem = get_required_var('XFSTESTS');
    my %para;
    if (check_var('XFSTESTS', 'ocfs2')) {
        install_dependencies_ocfs2;
    }
    if (check_var('XFSTESTS', 'overlay')) {
        install_dependencies_overlayfs;
        script_run("echo export UNIONMOUNT_TESTSUITE=/opt/unionmount-testsuite >> $CONFIG_FILE");
    }
    if (check_var('XFSTESTS', 'nfs')) {
        disable_and_stop_service(opensusebasetest::firewall, ignore_failure => 1);
        set_var('XFSTESTS_TEST_DEV', mountpoint_to_partition('/'));
        post_env_info(join(' ', get_partition_size('/')));
        if (get_var('XFSTESTS_NFS_SERVER')) {
            server_configure_network($self);
            install_dependencies_nfs;
            setup_nfs_server("$NFS_VERSION");
            setup_nfs_client("$NFS_VERSION");
            mutex_create('xfstests_nfs_server_ready');
            wait_for_children;
        }
        elsif (get_var('PARALLEL_WITH')) {
            setup_static_mm_network('10.0.2.102/24');
            install_dependencies_nfs;
            setup_pnfs_client if ($NFS_VERSION =~ 'pnfs');
            assert_script_run('mkdir -p /opt/nfs/test /opt/nfs/scratch');
            $NFS_SERVER_IP = '10.0.2.101';
        }
        else {
            install_dependencies_nfs;
            setup_nfs_server("$NFS_VERSION");
            setup_nfs_client("$NFS_VERSION");
            $NFS_SERVER_IP = 'localhost';
            $NFS_SERVER_IP = '127.0.0.1' if $NFS_VERSION =~ 'TLS';    #ipv6 will make some issue for the test key
            $NFS_SERVER_IP = script_output("ip route | awk 'NR==2 {print \$9}'") if $NFS_VERSION =~ 'rdma';
        }
        post_env_info(setup_xfstests_devices({mode => 'nfs', fstype => 'nfs'})) unless get_var('XFSTESTS_NFS_SERVER');
    }
    elsif ($device) {
        assert_script_run("parted $device --script -- mklabel gpt");
        my $dev_bytes = script_output("lsblk -bno SIZE $device");
        my $dev_mb = int($dev_bytes / (1024 * 1024));
        post_env_info(setup_xfstests_devices({mode => 'partition', fstype => $filesystem, dev => $device, size => "${dev_mb}M"}));
    }
    else {
        if ($loopdev) {
            my $rootsize = script_output("df -h | grep /\$ | awk -F \" \" \'{print \$4}\'");
            post_env_info(setup_xfstests_devices({mode => 'loop', fstype => $filesystem, size => $rootsize}));
        }
        elsif ($zonedev) {
            post_env_info(setup_xfstests_devices({mode => 'zoned', fstype => $filesystem}));
        }
        else {
            my $home_size = script_output("df -h | grep home | awk -F \" \" \'{print \$2}\'");
            post_env_info(setup_xfstests_devices({mode => 'partition', fstype => $filesystem, size => $home_size, delhome => 1}));
        }
    }
}

sub test_flags {
    return {fatal => 1};
}

1;

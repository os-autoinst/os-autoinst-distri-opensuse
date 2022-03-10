# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test the signed/unsigned module and kernel if can be loaded when secure-boot is enabled
# Maintainer: Liu Xiaojing <xiaojing.liu@suse.com>
# Tags: poo#108548

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;
    select_console 'root-console';

    zypper_call('in pesign-obs-integration');

    # Check if secure boot is enabled
    validate_script_output('dmesg | grep -i secure', sub { m/Secure boot mode enabled/ });
    validate_script_output('hexdump -C /proc/device-tree/ibm,secure-boot', sub { m/\d+\s+\d+\s+\d+\s+\d+\s+\d+/ });

    # Generate key
    my $work_dir = "/root/certs";
    my $cert_cfg = "$work_dir/secure_boot_cert.conf";
    my $priv_key = "$work_dir/key.pri";
    my $out_key = "$work_dir/key.der";
    my $config_file = 'openssl/gencert_conf/secure_boot_cert.conf';

    assert_script_run("mkdir -p $work_dir");
    assert_script_run("wget --quiet " . data_url($config_file) . " -O $cert_cfg");
    assert_script_run("openssl req -new -nodes -utf8 -sha256 -days 36500 -batch -x509 -config $cert_cfg -outform DER -out $out_key -keyout $priv_key");

    # Load module successfully when it has correct signature.
    my $kernel_version = script_output('uname -r');
    my $ufs_ko_file = "/lib/modules/$kernel_version/kernel/fs/ufs/ufs.ko";
    assert_script_run("zstd -d /lib/modules/$kernel_version/kernel/fs/ufs/ufs.ko.zst");
    validate_script_output("tail -c 28 $ufs_ko_file | hexdump -C", sub { m/Module signatur/ });
    assert_script_run("insmod $ufs_ko_file");

    assert_script_run('rmmod ufs');

    # Signed the module ko file with wrong signature which is gerenated by 'openssl'.
    # Fail to load the module due to the wrong key.
    assert_script_run("/usr/lib/rpm/pesign/kernel-sign-file sha256 $priv_key $out_key $ufs_ko_file");
    validate_script_output("insmod $ufs_ko_file 2>&1", sub { m /ERROR.*Key was rejected by service/ }, proceed_on_failure => 1);

    # Cleanup the module file
    script_run("rm $ufs_ko_file");

    # Fail to load the unsigned kernel by kexec
    my $kernel_file = "/boot/vmlinux-$kernel_version";
    my $kernel_backup_file = $kernel_file . '.backup';
    my $kernel_file_size = script_output("stat --printf=\"%s\\n\" $kernel_file");
    my $truncate_size = int($kernel_file_size) - 1;
    assert_script_run("cp $kernel_file $kernel_backup_file");
    assert_script_run("truncate -s $truncate_size $kernel_file");

    if (script_run("kexec -l $kernel_file -s") != 0) {
        record_info("Fail to load the unsigned kernel");
    }
    else {
        record_info("ERROR", "The unsigned kernel was loaded", result => "fail");
        $self->result("fail");
    }

    # Cleanup the unsigned kernel
    assert_script_run("mv $kernel_backup_file $kernel_file");

    # Load the signed kernel
    assert_script_run("kexec -l $kernel_file -s");
}

1;

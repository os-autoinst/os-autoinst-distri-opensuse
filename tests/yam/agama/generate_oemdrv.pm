## Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Generate OEMDRV disk from Agama Live ISO
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'Yam::Agama::agama_base';
use testapi;
use utils;
use autoyast qw(expand_agama_profile generate_json_profile);

sub run {
    my $self = shift;
    my $oemdrv_image = get_required_var('OEMDRV');
    my $profile_url = get_required_var('AGAMA_PROFILE');
    my $mount_point = '/mnt/oemdrv';

    select_console 'install-shell';

    zypper_call("ar -f -G https://download.suse.de/ibs/SUSE:/SLFO:/Products:/SLES:/" . get_var('VERSION') . ":/TEST/product/repo/SLES-" . get_var('VERSION') . "-" . get_var('ARCH') . "/?ssl_verify=no install");
    zypper_call("in --no-recommends -y qemu-tools");

    assert_script_run("mkdir -p tmp/oemdrv/root $mount_point");
    assert_script_run("curl -o tmp/oemdrv/root/autoinst.json $profile_url");

    assert_script_run("qemu-img create $oemdrv_image 100M -f qcow2");
    assert_script_run("modprobe nbd max_part=63");
    assert_script_run("qemu-nbd -c /dev/nbd0 $oemdrv_image");
    assert_script_run("parted --script /dev/nbd0 mklabel gpt mkpart primary ext4 1MiB 100%");
    assert_script_run("partprobe -s /dev/nbd0");
    assert_script_run("mkfs.ext4 -L OEMDRV /dev/nbd0p1");
    assert_script_run("mount /dev/nbd0p1 $mount_point");
    assert_script_run("cp tmp/oemdrv/root/autoinst.json $mount_point/");
    assert_script_run("umount $mount_point");
    assert_script_run("qemu-nbd --disconnect /dev/nbd0");
    assert_script_run("rmmod nbd");

    upload_asset($oemdrv_image);
}

1;

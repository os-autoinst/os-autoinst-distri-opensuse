## Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Injecting an installation profile into ISO image.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'Yam::Agama::patch_agama_base';
use testapi qw(assert_script_run autoinst_url data_url get_var record_info select_console set_var upload_asset script_run);
use utils;

sub run {
    my $arch = get_var('ARCH');
    my $test_iso = "/inject_profile_iso_" . $arch . ".iso";
    my $target_iso = '/agama-auto.iso';
    my $regcode = get_var('SCC_REGCODE');
    my $json_file = '/tmp/data.json';
    my $version = get_var('VERSION');

    select_console 'install-shell';
    assert_script_run('curl -f -o /tmp/data.jsonnet ' . autoinst_url("/data/yam/agama/auto/autoinst_oemdrv.jsonnet"));

    assert_script_run("jsonnet /tmp/data.jsonnet -o $json_file");

    assert_script_run("jq --arg code \"$regcode\" '.product.registrationCode = \$code' $json_file > $json_file.tmp && mv $json_file.tmp $json_file");
    record_info('cat /tmp/data.json');

    assert_script_run('mkdir -p /mnt/cdrom');
    assert_script_run('mount /dev/sr0 /mnt/cdrom');
    assert_script_run('mkdir -p /tmp/iso_workspace');
    assert_script_run('cp -r /mnt/cdrom/* /tmp/iso_workspace/');
    assert_script_run("cp $json_file /tmp/iso_workspace/autoinst.json");

    zypper_call("ar -f -G https://download.suse.de/ibs/SUSE:/SLFO:/Products:/SLES:/$version:/TEST/product/repo/SLES-$version-$arch/?ssl_verify=no install");
    zypper_call("in --no-recommends -y mkmedia");

    assert_script_run("mkmedia --create $test_iso /tmp/iso_workspace");

    script_run('sync');
    upload_asset($test_iso, 1);
    set_var('ISO', $test_iso);
}

1;

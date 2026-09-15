## Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Injecting an installation profile into ISO image.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'Yam::Agama::patch_agama_base';
use testapi qw(assert_script_run get_var get_required_var record_info select_console set_var upload_asset script_run);
use utils;
use autoyast qw(expand_agama_profile generate_json_profile);

sub run {
    my $arch = get_var('ARCH');
    my $test_iso = "/inject_profile_iso_" . $arch . ".iso";
    my $target_iso = '/agama-auto.iso';
    my $regcode = get_var('SCC_REGCODE');
    my $json_file = '/tmp/data.json';
    my $version = get_var('VERSION');
    my $profile = get_required_var('AGAMA_PROFILE');
    my $profile_url = generate_json_profile($profile);

    select_console 'install-shell';

    assert_script_run('curl -f -o /tmp/data.jsonnet ' . $profile_url);
    assert_script_run("jsonnet /tmp/data.jsonnet -o $json_file");

    record_info("cat $json_file");

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

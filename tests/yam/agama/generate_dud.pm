## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run interactive installation with Agama,
# using a web automation tool to test directly from the Live ISO.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base Yam::Agama::agama_base;
use testapi;
use utils;
use autoyast qw(expand_agama_profile generate_json_profile);

sub run {
    my $self = shift;
    my $archived_dud_with_profile = get_required_var('DUD');
    my $profile_url = get_required_var('AGAMA_PROFILE');

    select_console 'install-shell';

    # https://progress.opensuse.org/issues/185122
    zypper_call("ar -f -G https://download.suse.de/ibs/SUSE:/SLFO:/Products:/SLES:/" . get_var('VERSION') . ":/PUBLISH/product/repo/SLES-" . get_var('VERSION') . "-" . get_var('ARCH') . "/?ssl_verify=no install");
    # temporal pointing a new ticket: https://progress.opensuse.org/issues/195371.
    # repo needed to install mkdud, the previous repo still needed for installation
    # of other packages. Remove it after verified on Beta.
    zypper_call("ar -f -G  https://download.suse.de/ibs/home:/epaolantonio:/main_mkdud/standard/" . "/?ssl_verify=no install_mkdud");
    zypper_call("in -y mkdud");
    assert_script_run("mkdir -p tmp/dud/root");
    assert_script_run("curl -o tmp/dud/root/autoinst.json $profile_url");
    assert_script_run("mkdud --create $archived_dud_with_profile tmp/dud/root --dist tw");
    upload_asset($archived_dud_with_profile);

    my $arch = get_required_var('ARCH');
    my $archived_dud_with_kernel_module = "kernel-" . $arch . ".dud";
    assert_script_run("mkdud --create $archived_dud_with_kernel_module --arch $arch --dist sle16 /lib/modules/`uname -r`/kernel/fs/nfs/nfs.ko");
    upload_asset($archived_dud_with_kernel_module);
}

1;

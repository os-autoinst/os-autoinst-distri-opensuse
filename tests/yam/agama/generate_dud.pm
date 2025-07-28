## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run interactive installation with Agama,
# using a web automation tool to test directly from the Live ISO.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::agama_base;
use testapi;
use utils;
use autoyast qw(expand_agama_profile generate_json_profile);

sub run {
    my $self = shift;
    my $dud = get_required_var('DUD');
    my $profile_url = get_required_var('AGAMA_PROFILE');

    select_console 'install-shell';

    # https://progress.opensuse.org/issues/185122
    zypper_call("ar -f -G https://download.opensuse.org/repositories/home:/snwint:/ports/SLFO-Main/home:snwint:ports.repo");
    zypper_call("in -y mkdud");
    assert_script_run("mkdir -p tmp/dud/root");
    assert_script_run("curl -o tmp/dud/root/autoinst.json $profile_url");
    assert_script_run("mkdud --create $dud tmp/dud/root --dist tw");
    upload_asset($dud);
}

1;

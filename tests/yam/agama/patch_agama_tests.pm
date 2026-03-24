## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Patch Agama on Live Medium using yupdate in order to copy
# integration test from GitHub.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base Yam::Agama::patch_agama_base;
use testapi qw(assert_script_run get_required_var select_console script_output);

sub run {
    select_console 'install-shell';
    my ($repo, $branch) = split /#/, get_required_var('YUPDATE_GIT');

    # Network workaround ensuring stability by reducing MTU
    my $iface = script_output('ip -j r s | jq -r ".[] | select(.dst == \"default\") | .dev"');
    assert_script_run("ip link set dev $iface mtu 1000");

    assert_script_run("AGAMA_TEST=" . get_required_var('AGAMA_TEST') . " yupdate patch $repo $branch", timeout => 60);
}

1;

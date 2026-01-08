## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run Agama profile import on Live Medium
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base Yam::Agama::patch_agama_base;
use testapi qw(assert_script_run data_url get_required_var set_var get_var check_var select_console script_run);
use autoyast qw(expand_agama_profile generate_json_profile);

sub run {
    my $profile = get_required_var('AGAMA_PROFILE');
    my $profile_url = ($profile =~ /\.libsonnet/) ?
      generate_json_profile($profile) :
      expand_agama_profile($profile);
    set_var('AGAMA_PROFILE', $profile_url);

    select_console 'install-shell';
    assert_script_run("agama config load $profile_url", timeout => 300) if (!check_var('AGAMA_PROFILE_LOAD', '0'));
}

1;

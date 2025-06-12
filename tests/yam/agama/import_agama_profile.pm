## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run Agama profile import on Live Medium
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::patch_agama_base;
use strict;
use warnings;
use testapi qw(assert_script_run data_url get_required_var select_console script_run);
use autoyast qw(expand_agama_profile generate_json_profile);

sub run {
    my $profile = get_required_var('AGAMA_PROFILE');
    my $profile_url = ($profile =~ /\.libsonnet/) ?
      generate_json_profile($profile) :
      expand_agama_profile($profile);

    select_console 'install-shell';
    assert_script_run("agama profile import $profile_url", timeout => 300);
}

1;

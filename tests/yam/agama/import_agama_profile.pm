## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Run Agama profile import on Live Medium
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'Yam::Agama::patch_agama_base';
use testapi qw(assert_script_run data_url get_required_var set_var get_var check_var select_console script_run record_soft_failure);
use autoyast qw(expand_agama_profile generate_json_profile);
use version_utils qw(is_sle);

sub run {
    my $profile = get_required_var('AGAMA_PROFILE');
    my $profile_url = ($profile =~ /\.libsonnet/) ?
      generate_json_profile($profile) :
      expand_agama_profile($profile);
    set_var('AGAMA_PROFILE', $profile_url);

    select_console 'install-shell';
    my $enable_workaround = (is_sle('16.1+') && get_var('FLAVOR', '') =~ /Online|Full/);
    my $workaround = $enable_workaround ? " > /dev/null" : "";
    record_soft_failure("bsc#1265431 - Agama config load blocks in BUSY state") if $enable_workaround;
    assert_script_run("agama config load $profile_url" . $workaround, timeout => 300) if (!check_var('AGAMA_PROFILE_LOAD', '0'));
}

1;

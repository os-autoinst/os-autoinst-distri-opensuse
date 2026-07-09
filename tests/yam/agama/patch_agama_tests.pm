## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Patch Agama on Live Medium using yupdate in order to copy
# integration test from GitHub.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::patch_agama_base;
use testapi qw(assert_script_run get_required_var select_console script_run record_info save_tmp_file autoinst_url);

sub run {
    select_console 'install-shell';
    my $agama_test = get_required_var("AGAMA_TEST");
    my ($repo, $branch) = split /#/, get_required_var('YUPDATE_GIT');
    my $tar_name = 'dist.tar.gz';
    my $destination = "/usr/share/agama/system-tests";
    my $podman_command = "podman run --rm -v ./:/tmp/output " .
          "okynos/agama-integration-test-webpack-builder:latest " .
          get_required_var('YUPDATE_GIT');

    my $podman_output = qx{$command};
    record_info('podman', $podman_output);

    my $tar_data = `cat $tar_name`;
    save_tmp_file($tar_name, $tar_data);

    my $tar_url = autoinst_url("/files/$tar_name");
    script_run("curl -OL $tar_url");
    script_run("tar -C '$destination' -xzf $tar_name");
}

1;

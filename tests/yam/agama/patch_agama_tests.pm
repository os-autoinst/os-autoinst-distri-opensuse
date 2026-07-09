## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Patch Agama on Live Medium using yupdate in order to copy
# integration test from GitHub.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base Yam::Agama::patch_agama_base;
use testapi qw(assert_script_run get_required_var select_console script_run record_info save_tmp_file autoinst_url);

sub run {
    select_console 'install-shell';
    my $tar_name = 'dist.tar.gz';
    my $destination = "/usr/share/agama/system-tests";
    my $podman_command = "/usr/bin/podman run --rm " .
          "--storage-opt ignore_chown_errors=true " .
          "--cgroup-manager=cgroupfs " .
          "--root ./ " .
          "-v './:/tmp/output' " .
          "docker.io/okynos/agama-integration-test-webpack-builder:latest " .
          get_required_var('YUPDATE_GIT');

    record_info('command', $podman_command);
    my $podman_output = qx{$command 2>&1};
    my $podman_exit_code = $? >> 8;
    my $pwd = qx{pwd};
    record_info('pwd', $pwd);
    my $podman_version = qx{/usr/bin/podman --root $pwd --version 2>&1};
    record_info('version', $podman_version);
    record_info('podman', $podman_output);
    record_info('exit', $podman_exit_code);

    my $folder_ls = `ls -lah`;
    record_info('folder', $folder_ls);

    my $tar_data = `cat $tar_name`;
    save_tmp_file($tar_name, $tar_data);

    my $tar_url = autoinst_url("/files/$tar_name");
    script_run("curl -OL $tar_url");
    script_run("tar -C '$destination' -xzf $tar_name");
}

1;

# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: tar
# Summary: -  Verify the correct version of tar is in 15-SP4
#          -  tar + zstd functionality automatic test
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle);

sub run {
    select_serial_terminal;

    assert_script_run "wget --quiet " . data_url('console/tar_test.tar');
    assert_script_run("tar -xvf tar_test.tar");

    # - compress -j and extract
    assert_script_run("tar -cjvf myfile.tar.bz2 tar_test");
    assert_script_run("tar -xjvf myfile.tar.bz2 -C /tmp/");
    assert_script_run("rm -rf /tmp/tar_test");

    # - compress -J and extract
    assert_script_run("tar -cJvf myfile.tar.xz tar_test");
    assert_script_run("tar -xJvf myfile.tar.xz -C /tmp/");
    assert_script_run("rm -rf /tmp/tar_test");

    # - compress -z and extract
    assert_script_run("tar -czvf myfile.tar.gz tar_test");
    assert_script_run("tar -xzvf myfile.tar.gz -C /tmp/");
    assert_script_run("rm -rf /tmp/tar_test");

    # - compress -a file.tar.gzip and extract
    assert_script_run("tar -cavf myfile.tar.gz tar_test");
    assert_script_run("tar -xavf myfile.tar.gz -C /tmp/");
    assert_script_run("rm -rf /tmp/tar_test");

    if (is_sle('>=15-sp1')) {
        zypper_call("in zstd");

        # - compress -I zstd and extract
        assert_script_run("tar -I zstd -cvf myfile.tar.zst tar_test");
        assert_script_run("tar -I zstd -xvf myfile.tar.zst -C /tmp/");
        assert_script_run("rm -rf /tmp/tar_test");
    }

    if (is_sle('>=15-sp4')) {
        # - compress --zstd and extract
        assert_script_run("tar --zstd -cvf myfile.tar.zst tar_test");
        assert_script_run("tar --zstd -xvf myfile.tar.zst -C /tmp/");
        assert_script_run("rm -rf /tmp/tar_test");

        # - compress -acvf myfile.tar.zstd and extract tar xvf package.tar.zst
        assert_script_run("tar -cavf myfile.tar.zst tar_test");
        assert_script_run("tar -xavf myfile.tar.zst -C /tmp/");
        assert_script_run("rm -rf /tmp/tar_test");

    }

}

1;

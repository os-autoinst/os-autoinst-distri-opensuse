# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Fortran test
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

sub run {
    my $self = shift;

    my $package_main = data_url('toolchain/fcvs21_f95.tar.bz2');
    my $package_fix = data_url('toolchain/FM923.DAT');
    my $package_patch1 = data_url('toolchain/adapt-FM406-to-fortran-95.patch');
    my $package_patch2 = data_url('toolchain/FM509-remove-TEST-016.patch');

    foreach my $pkg ($package_main, $package_fix, $package_patch1, $package_patch2) {
        my $file_name = (split(/\//, $pkg))[-1];
        assert_script_run "curl $pkg --output $file_name";
    }

    assert_script_run 'tar jxf fcvs21_f95.tar.bz2';
    assert_script_run 'cp FM923.DAT fcvs21_f95/';
    assert_script_run 'pushd fcvs21_f95';

    # gfortran (and gcc) fixed to version in SLE12 after the yearly gcc update with Toolchain module
    my $fortran_version = (is_sle('<15') || is_leap('<15.0')) ? 'gfortran-5' : 'gfortran';

    assert_script_run "sed -i 's/g77/$fortran_version/g' driver_*";
    assert_script_run 'echo "exit \${failed}" >> driver_parse';

    assert_script_run 'patch -p0 < ../adapt-FM406-to-fortran-95.patch';
    assert_script_run 'patch -p0 < ../FM509-remove-TEST-016.patch';
    assert_script_run 'rm FM001.f FM005.f FM109.f FM257.f';

    # Build
    assert_script_run './driver_parse 2>&1 | tee /tmp/build.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi', 120;
    # Test
    assert_script_run './driver_run 2>&1 | tee /tmp/test.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi', 300;
    # Verify
    assert_script_run('! grep -P -L "(0 TESTS FAILED|0 ERRORS ENCOUNTERED)" *.res | grep FM');

    assert_script_run 'popd';
}

sub post_fail_hook {
    my $self = shift;

    upload_logs '/tmp/build.log';
    upload_logs '/tmp/test.log';
    script_run 'tar cfJ fcvs21_f95_results.tar.xz *.res';
    upload_logs 'fcvs21_f95_results.tar.xz';
    script_run 'popd';
}

1;

# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Fortran test for SLE Toolchain Module's GCC5
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    my $package_main  = data_url('toolchain/fcvs21_f95.tar.bz2');
    my $package_fix   = data_url('toolchain/FM923.DAT');
    my $package_patch = data_url('toolchain/adapt-FM406-to-fortran-95.patch');
    assert_script_run "wget $package_main",  60;
    assert_script_run "wget $package_fix",   60;
    assert_script_run "wget $package_patch", 60;
    script_run 'tar jxf fcvs21_f95.tar.bz2';
    script_run 'cp FM923.DAT fcvs21_f95/';
    script_run 'pushd fcvs21_f95';
    script_run "sed -i 's/g77/gfortran-5/g' driver_*";
    script_run 'echo "exit \${failed}" >> driver_parse';

    script_run "patch -p0 < ../adapt-FM406-to-fortran-95.patch";
    script_run "rm FM001.f FM005.f FM109.f FM257.f";

    # Build
    assert_script_run './driver_parse 2>&1 | tee /tmp/build.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi', 120;
    # Test
    assert_script_run './driver_run 2>&1 | tee /tmp/test.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi', 300;
    # Verify
    assert_script_run('! grep -P -L "(0 TESTS FAILED|0 ERRORS ENCOUNTERED)" *.res | grep FM');

    save_screenshot;
    script_run 'popd';
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
    upload_logs '/tmp/build.log';
    upload_logs '/tmp/test.log';
    script_run 'tar cfJ fcvs21_f95_results.tar.xz *.res';
    upload_logs 'fcvs21_f95_results.tar.xz';
    script_run 'popd';
}

1;
# vim: set sw=4 et:

# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
    script_run 'cd fcvs21_f95';
    script_run "sed -i 's/g77/gfortran-5/g' driver_*";
    script_run 'echo "exit \${failed}" >> driver_parse';

    script_run "patch -p0 < ../adapt-FM406-to-fortran-95.patch";

    # Build
    assert_script_run './driver_parse|tee /tmp/build.log', 120;
    # Test
    assert_script_run './driver_run|tee /tmp/test.log', 300;

    assert_script_run('! grep " [1-9][0-9]* TESTS FAILED" *.res', fail_message => 'fortran tests failed');

    save_screenshot;
}

sub test_flags() {
    return {important => 1};
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
    upload_logs '/tmp/build.log';
    upload_logs '/tmp/test.log';
}

1;
# vim: set sw=4 et:

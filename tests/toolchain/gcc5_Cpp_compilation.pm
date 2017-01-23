# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: C++ toolchain module test
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    script_run 'zypper -v -n in cmake';
    my $package = data_url('toolchain/llvm-3.8.1.src.tar.xz');
    script_run "wget $package";
    $package = data_url('toolchain/cfe-3.8.1.src.tar.xz');
    script_run "wget $package";
    script_run 'tar xf llvm-3.8.1.src.tar.xz';
    script_run 'tar xf cfe-3.8.1.src.tar.xz';
    script_run 'mv cfe-3.8.1.src llvm-3.8.1.src/tools/clang/';
    script_run 'mkdir mybuilddir; pushd mybuilddir';
    # Documentation (http://llvm.org/docs/HowToBuildOnARM.html) suggest to use "Release"
    # build type and limit itself to build ARM targets only (plus Intel target for
    # Compiler-RT tests). Otherwise OOM killer kicks in.
    my $configure_options = '-DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD="X86';
    if (check_var('ARCH', 'aarch64')) {
        $configure_options .= ';AArch64"';
    }
    elsif (check_var('ARCH', 'ppc64le')) {
        $configure_options .= ';PowerPC"';
    }
    elsif (check_var('ARCH', 's390x')) {
        $configure_options .= ';SystemZ"';
    }
    elsif (check_var('ARCH', 'x86_64')) {
        $configure_options .= '"';
    }
    assert_script_run
"cmake ../llvm-3.8.1.src $configure_options 2>&1 | tee /tmp/configure.log; if [ \${PIPESTATUS[0]} -ne 0 ]; then false; fi",
      200;
    assert_script_run
      'make -j$(getconf _NPROCESSORS_ONLN) 2>&1 | tee /tmp/make.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi',
      6000;
    script_run 'pushd tools/clang/test';
    assert_script_run
'make -j$(getconf _NPROCESSORS_ONLN) 2>&1 | tee /tmp/make-clang.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi',
      6000;
    script_run 'popd';
    assert_script_run
'make check-all -j$(getconf _NPROCESSORS_ONLN) 2>&1 | tee /tmp/make_test.log; if [ ${PIPESTATUS[0]} -ne 0 ]; then false; fi',
      1800;
    script_run 'popd';
}

sub test_flags() {
    return {important => 1};
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
    upload_logs '/tmp/configure.log';
    upload_logs '/tmp/make.log';
    upload_logs '/tmp/make-clang.log';
    upload_logs '/tmp/make_test.log';
    script_run 'cd';
}

1;
# vim: set sw=4 et:

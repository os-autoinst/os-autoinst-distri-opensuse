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

    my $package = data_url('toolchain/llvm-3.6.2.src.tar.xz');
    script_run "wget $package";
    $package = data_url('toolchain/cfe-3.6.2.src.tar.xz');
    script_run "wget $package";
    script_run 'tar xf llvm-3.6.2.src.tar.xz';
    script_run 'tar xf cfe-3.6.2.src.tar.xz';
    script_run 'mkdir llvm-3.6.2.src/tools/clang';
    script_run 'mv cfe-3.6.2.src/* llvm-3.6.2.src/tools/clang/';
    script_run 'cd llvm-3.6.2.src';
    assert_script_run './configure --disable-bindings|tee /tmp/configure.log', 100;
    assert_script_run 'make -j$(getconf _NPROCESSORS_ONLN)|tee /tmp/make.log', 4000;
    script_run 'cd tools/clang';
    assert_script_run 'make test|tee /tmp/make_test.log', 500;
}

sub test_flags() {
    return {important => 1};
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
    upload_logs '/tmp/configure.log';
    upload_logs '/tmp/make.log';
    upload_logs '/tmp/make_test.log';
}

1;
# vim: set sw=4 et:

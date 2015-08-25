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
    assert_script_run './configure --disable-bindings', 100;
    assert_script_run 'make -j$(getconf _NPROCESSORS_ONLN)', 3000;
    script_run 'cd tools/clang';
    assert_script_run 'make test', 500;
}

sub test_flags() {
    return { 'important' => 1 };
}

1;
# vim: set sw=4 et:

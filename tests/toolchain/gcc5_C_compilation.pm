use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;

    script_run 'export CC=/usr/bin/gcc-5';
    script_run 'export CXX=/usr/bin/g++-5';
    my $package = data_url('toolchain/ltp-full-20150420.tar.bz2');
    script_run "wget $package";
    script_run 'tar jxf ltp-full-20150420.tar.bz2';
    script_run 'cd ltp-full-20150420';
    script_run 'setterm -blank 0';    # disable screensaver
    assert_script_run './configure --with-open-posix-testsuite', 100;
    assert_script_run 'make all',                                800;
    assert_script_run 'make install',                            400;
    script_run 'cd /opt/ltp/';
    script_run "./runltp -f syscalls;echo runltp syscalls PASSED-\$?|tee /dev/$serialdev";
    wait_serial('runltp syscalls PASSED-[01]', 1200) || die 'runltp syscalls FAILED';
    script_run 'cat output/*.failed';    # print what tests failed
    sleep 5;
    save_screenshot;
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:

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

    my $package = data_url('toolchain/ltp-full-20150420.tar.bz2');
    script_run "wget $package";
    script_run 'tar jxf ltp-full-20150420.tar.bz2';
    script_run 'cd ltp-full-20150420';
    assert_script_run './configure --with-open-posix-testsuite|tee /tmp/configure.log', 600;
    assert_script_run 'make all|tee /tmp/make_all.log',                                 3600;
    assert_script_run 'make install|tee /tmp/make_install.log',                         600;
    script_run 'cd /opt/ltp/';
    assert_script_run './runltp -f syscalls|tee /tmp/runltp.log', 2000;
    script_run 'cat output/*.failed';    # print what tests failed
    sleep 5;
    save_screenshot;
}

sub test_flags() {
    return {important => 1};
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
    upload_logs '/tmp/configure.log';
    upload_logs '/tmp/make_all.log';
    upload_logs '/tmp/make_install.log';
    upload_logs '/tmp/runltp.log';
}

1;
# vim: set sw=4 et:

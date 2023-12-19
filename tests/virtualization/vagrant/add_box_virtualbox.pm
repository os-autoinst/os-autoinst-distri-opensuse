# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: vagrant
# Summary: Test for vagrant
# Maintainer: dancermak <dcermak@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use vagrant;

sub run() {
    setup_vagrant_virtualbox();

    select_console('user-console');
    assert_script_run('echo "test" > testfile');

    run_vagrant_cmd('init centos/7');
    run_vagrant_cmd('up --provider virtualbox', timeout => 1200);

    run_vagrant_cmd('ssh -c "[ $(cat testfile) = \"test\" ]"');
    run_vagrant_cmd('halt');
    run_vagrant_cmd('destroy -f');

    assert_script_run('rm -rf Vagrantfile testfile .vagrant');
}

sub post_fail_hook() {
    my ($self) = @_;

    upload_logs($vagrant_logfile);
    assert_script_run('rm -rf Vagrantfile testfile .vagrant');
    $self->SUPER::post_fail_hook;
}

1;

# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation of munge package from HPC module and sanity check
# of this package
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, soulofdestiny <mgriessmeier@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;

sub exec_and_insert_password {
    my ($cmd) = @_;
    type_string $cmd;
    send_key "ret";
    assert_screen 'password-prompt';
    type_password;
    send_key "ret";
}

sub run() {
    # set proper hostname
    assert_script_run('hostnamectl set-hostname munge-master');

    zypper_call('in munge libmunge2');
    barrier_wait('MUNGE_INSTALLED');
    exec_and_insert_password(
        'scp -o StrictHostKeyChecking=no /etc/munge/munge.key root@172.16.0.23:/etc/munge/munge.key');
    barrier_wait('MUNGE_KEY_COPY');
    assert_script_run('systemctl enable munge.service');
    assert_script_run('systemctl start munge.service');
    barrier_wait('MUNGE_SERVICE_START');
    assert_script_run('munge -n');
    assert_script_run('munge -n | unmunge');
    exec_and_insert_password('munge -n | ssh 172.16.0.23 unmunge');
    assert_script_run('remunge');
    barrier_wait('TEST_END');
}

1;

# vim: set sw=4 et:


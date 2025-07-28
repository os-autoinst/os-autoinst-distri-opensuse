# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run a ssh client to test firstboot wizard ssh enrollment feature
# Maintainer: QE-C team <qa-c@suse.de>

use base "consoletest";
use testapi;
use lockapi qw(mutex_wait);
use mmapi;

sub run {
    select_console 'root-console';
    script_run("ssh-keygen -t rsa -b 2048 -f id_rsa -N ''");

    my $children = get_children();
    my $child_id = (keys %$children)[0];
    mutex_wait('SSH_ENROLL_PAIR', $child_id);

    script_run("ssh -i id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root\@10.0.2.15");
}

1;

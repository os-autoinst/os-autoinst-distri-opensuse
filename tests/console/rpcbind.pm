# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: rpcbind test
# Maintainer: Jozef Pupava <jpupava@suse.com>

use warnings;
use base 'consoletest';
use strict;
use testapi;
use utils qw(systemctl zypper_call);

sub run {
    my ($self) = @_;
    $self->select_serial_terminal();
    zypper_call 'in rpcbind nfs-kernel-server';
    assert_script_run 'rpm -q rpcbind';

    # start libvirt hypervisor for vhostmd
    systemctl 'start rpcbind';
    systemctl 'status rpcbind';
    assert_script_run 'rpcinfo';

    # create and start nfs export
    assert_script_run 'echo "/mnt *(ro,root_squash,sync,no_subtree_check)" >/etc/exports';
    assert_script_run 'echo "nfs is working" >/mnt/test';
    systemctl 'start nfsserver';
    systemctl 'status nfsserver';

    # wait for updated rpcinfo
    sleep 5;
    assert_script_run 'rpcinfo|grep nfs';
    assert_script_run 'mkdir -p /tmp/nfs';
    assert_script_run 'mount -t nfs localhost:/mnt /tmp/nfs';
    assert_script_run 'grep working /tmp/nfs/test';
    assert_script_run 'umount -f /tmp/nfs';
}

sub post_run_hook {
    # stop started services
    systemctl 'stop rpcbind.socket rpcbind.service nfsserver';
}

1;

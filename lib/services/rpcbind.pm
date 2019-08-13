# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Package for rpcbind service tests
#
# Maintainer: Alynx Zhou <alynx.zhou@suse.com>

package services::rpcbind;
use base 'opensusebasetest';
use testapi;
use utils;
use strict;
use warnings;

sub install_service {
    # rpcbind needs nfs-server for testing.
    zypper_call('in rpcbind');
    zypper_call('in nfs-kernel-server');
}

sub check_install {
    assert_script_run("rpm -q rpcbind");
    assert_script_run("rpm -q nfs-kernel-server");
}

sub config_service {
    type_string("echo '/mnt *(ro,root_squash,sync,no_subtree_check)' > /etc/exports\n");
    type_string("echo 'nfs is working' > /mnt/test\n");
}

sub enable_service {
    systemctl('enable rpcbind');
    systemctl('enable nfs-server');
}

sub start_service {
    systemctl('start rpcbind');
    systemctl('start nfs-server');
}

sub stop_service {
    systemctl('stop rpcbind');
    systemctl('stop nfs-server');
}

sub check_service {
    systemctl('is-enabled rpcbind');
    systemctl('is-active rpcbind');
}

sub check_function {
    assert_script_run("rpcinfo");
    # Wait for updated rpcinfo.
    sleep(5);
    assert_script_run('rpcinfo | grep nfs');
    assert_script_run('mkdir -p /tmp/nfs');
    assert_script_run('mount -t nfs localhost:/mnt /tmp/nfs');
    sleep(3);
    assert_script_run('grep working /tmp/nfs/test');
    assert_script_run('umount -f /tmp/nfs');
}

# Check rpcbind service before and after migration.
# Stage is 'before' or 'after' system migration.
sub full_rpcbind_check {
    my ($stage) = @_;
    $stage //= '';
    if ($stage eq 'before') {
        install_service();
        config_service();
        enable_service();
        start_service();
    }
    check_service();
    check_function();
}

1;

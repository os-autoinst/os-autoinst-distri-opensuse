# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "hacluster";
use testapi;
use autotest;
use lockapi;

sub run() {
    my $self            = shift;
    my $ocfs2_partition = "/dev/disk/by-path/ip-*-lun-2";
    $self->barrier_wait("OCFS2_INIT");
    type_string "rpm -q ocfs2-kmp-default; echo ocfs2_kmp_default_installed=$?\n";
    if (!wait_serial "ocfs2_kmp_default_installed=0") {    #workaround for bsc#976634
        record_soft_failure "ocfs2-kmp-default is not installed";
        assert_script_run "zypper in -y ocfs2-kmp-default";
    }
    type_string "ps -A | grep -q dlm_controld; echo dlm_running=\$? > /dev/$serialdev\n";
    die "dlm_controld is not running" unless wait_serial "dlm_running=0", 60;
    if ($self->is_node1) {
        type_string "mkfs.ocfs2 $ocfs2_partition; echo mkfs_ocfs2=\$? > /dev/$serialdev\n";
        die "mkfs.ocfs2 failed" unless wait_serial "mkfs_ocfs2=0", 60;
    }
    else {
        type_string "echo wait until OCFS2 is formatted\n";
    }
    $self->barrier_wait("OCFS2_MKFS_DONE");
    if ($self->is_node1) {
        type_string "echo wait until OCFS2 resource is created\n";
    }
    else {
        type_string qq(EDITOR="sed -ie '\$ a primitive ocfs2-1 ocf:heartbeat:Filesystem params device='`ls -1 $ocfs2_partition`' directory="/srv/ocfs2" fstype="ocfs2" options="acl" op monitor interval=20 timeout=40'" crm configure edit; echo ocfs2_add=\$? > /dev/$serialdev\n);
        die "create OCFS2 resource failed" unless wait_serial "ocfs2_add=0", 60;
        type_string qq(EDITOR="sed -ie 's/group base-group dlm/group base-group dlm ocfs2-1/'" crm configure edit; echo base_group_alter=\$? > /dev/$serialdev\n);
        die "adding ocfs2-1 to base-group failed" unless wait_serial "base_group_alter=0", 60;
    }
    $self->barrier_wait("OCFS2_GROUP_ALTERED");
    if ($self->is_node1) {
        type_string "cp -r /usr/bin/ /srv/ocfs2; echo copy_success=\$? > /dev/$serialdev\n";
        die "copying files to /srv/ocfs2 failed" unless wait_serial "copy_success=0", 60;
        type_string "cd /srv/ocfs2; find bin/ -exec md5sum {} \\; > out; echo md5sums=\$? > /dev/$serialdev\n";
        die "calculating md5sums failed" unless wait_serial "md5sums=0", 60;
    }
    else {
        type_string "echo wait until OCFS2 is filled with data\n";
    }
    $self->barrier_wait("OCFS2_DATA_COPIED");
    if ($self->is_node1) {
        type_string "echo wait until OCFS2 content is checked\n";
    }
    else {
        type_string "cd /srv/ocfs2; find bin/ -exec md5sum {} \\; > out_node2; echo md5sums=\$? > /dev/$serialdev\n";
        die "calculating md5sums failed" unless wait_serial "md5sums=0", 60;
        type_string "diff out out_node2; echo md5sums_diff=\$? > /dev/$serialdev\n";
        die "md5sums are different on different nodes" unless wait_serial "md5sums_diff=0", 60;
    }
    $self->barrier_wait("OCFS2_MD5_CHECKED");
}

1;

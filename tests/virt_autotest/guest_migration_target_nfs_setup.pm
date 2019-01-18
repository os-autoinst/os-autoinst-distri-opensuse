# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: Virtualization multi-machine job : Guest Migration
# Maintainer: jerry <jtang@suse.com>

use base multi_machine_job_base;
use strict;
use warnings;
use testapi;
use lockapi;
use mmapi;
use guest_migration_base;

sub run {
    my ($self) = @_;

    #Sync the setting for ip address
    mutex_create('ip_set_done');

    #Manually sync the setting for child nfs address
    $self->workaround_for_reverse_lock('NFS_DONE', 1800);

    my $nfs_server = $self->get_var_from_child('MY_IP');

    #Setup /etc/hosts
    $self->set_hosts('parent');

    #Mount the share storage
    my $cmd_mount_disk_dir = "mount -t nfs -o vers=4,nfsvers=4 $nfs_server:$nfs_local_dir $vm_disk_dir";
    $self->execute_script_run($cmd_mount_disk_dir, 500);
    save_screenshot;
    mutex_create('nfs_done');
    save_screenshot;

    #Clean the VM
    my $cmd_clean_vm = q(virsh list --all|awk 'NR>2{print $2}'|sed '$d'|xargs -i virsh undefine {});
    $self->execute_script_run($cmd_clean_vm, 500);


    #Setup the bridge
    $self->execute_script_run('bash /usr/share/qa/qa_test_virtualization/shared/standalone', 500);
    mutex_create('bridge_done');
    save_screenshot;

    #Clean the VM
    $self->execute_script_run($cmd_clean_vm, 500);
    mutex_create('clean_vm_done');
    save_screenshot;

    wait_for_children;
}

1;

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

    #Sync the setup for ip address
    mutex_lock('ip_set_done');
    mutex_unlock('ip_set_done');

    #set hosts
    $self->set_hosts('child');

    #Change the nfs config
    my $cmd_modify_nfs_config = q(sed -i 's/^NFSV4LEASETIME=.*$/NFSV4LEASETIME="10"/' /etc/sysconfig/nfs);
    $self->execute_script_run($cmd_modify_nfs_config, 500);

    my $nfs_server        = get_var('MY_IP');
    my $cmd_write_exports = qq(echo "$nfs_local_dir *(rw,sync,no_root_squash,no_subtree_check)" >/etc/exports);
    $self->execute_script_run($cmd_write_exports, 500);

    #Restart the nfs service
    $self->execute_script_run("rcnfs-server restart", 500);
    set_var('NFS_DONE', 1);
    bmwqemu::save_vars();

    #Mount the share storage
    my $cmd_mount_disk_dir = qq(mount -t nfs -o vers=4,nfsvers=4 $nfs_server:$nfs_local_dir $vm_disk_dir);
    $self->execute_script_run($cmd_mount_disk_dir, 500);
    mutex_lock('nfs_done');
    mutex_unlock('nfs_done');

    #Sync the bridge setting
    mutex_lock('bridge_done');
    mutex_unlock('bridge_done');

    #Sync the vm clean
    mutex_lock('clean_vm_done');
    mutex_unlock('clean_vm_done');
}

1;

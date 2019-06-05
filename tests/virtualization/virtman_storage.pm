# Copyright (C) 2014-2017 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: - add the virtualization test suite- add a load_virtualization_tests call
# Maintainer: aginies <aginies@suse.com>

use base 'x11test';
use strict;
use warnings;
use testapi;
use virtmanager;
use utils;


sub go_for_pool {
    my $pool = shift;
    launch_virtmanager();
    # go tab storage
    connection_details('storage');
    create_new_pool($pool);
    # close virt-manager and xterm
    send_key 'ctrl-w';
}

sub go_for_volume {
    my ($poolnb) = @_;
    # define all formats to test
    my @formats = ('raw', 'qcow', 'qcow2', 'qed', 'vmdk', 'vpc', 'vdi');
    # define a basic volume
    my $newvolume = {
        pool         => 'openQA_dir',    # not yet used... FIXME
        name         => 'VOL',
        format       => 'cow',
        maxcapacity  => '0.2',           # low capacity to avoid not enough space
        allocation   => '0.1',
        backingstore => '',              # only qcow2
    };
    launch_virtmanager();
    connection_details('storage');
    # got to pool
    wait_screen_change { send_key 'tab' };
    for (0 .. $poolnb) {
        wait_screen_change { send_key 'down' };
    }
    # do all other format available
    foreach my $format (@formats) {
        # all other previous declaration are OK
        $newvolume->{name}   = 'VOL' . $poolnb . '_' . $format;
        $newvolume->{format} = $format;
        create_new_volume($newvolume);
    }
}

sub create_nfs_share {
    my ($dir) = @_;
    x11_start_program('xterm');
    become_root();
    assert_script_run "mkdir -p $dir";
    assert_script_run "echo '$dir *(rw,sync)' >> /etc/exports";
    systemctl 'restart nfs-server';
    assert_script_run "exportfs";
    type_string 'exit';
    send_key 'ret';
}

sub checking_storage_result {
    my $volumes = shift;
    x11_start_program('xterm');
    send_key 'alt-f10';
    become_root();
    assert_script_run 'virsh -c qemu:///system pool-list';
    foreach my $vol (@$volumes) {
        assert_script_run "virsh -c qemu:///system vol-list $vol";
    }
    assert_screen 'virtman_storagecheck';
}


sub run {
    # ! pool type gluster is not supported !
    # 1 pool type DIR: target path
    my $newpool = {
        name => 'openQA_dir',
        data => {
            type        => 'dir',
            target_path => '/var/lib/libvirt/images/openQA_dir',
        },
    };
    go_for_pool($newpool);
    go_for_volume('1');

    # 2 mpath: target path (/dev/mapper)
    $newpool = {
        name => 'openQA_mpath',
        data => {
            type        => 'mpath',
            target_path => '/dev/mapper',
        },
    };
    go_for_pool($newpool);

    # 3 netfs:  target path; hostname; source path
    $newpool = {
        name => 'openQA_netfs',
        data => {
            type        => 'netfs',
            target_path => '/var/lib/libvirt/images/netfs',
            hostname    => 'localhost',
            source_path => '/data',
        },
    };
    create_nfs_share($newpool->{data}{source_path});
    go_for_pool($newpool);
    #    go_for_volume('3');

    # 4 pool type DISK: target path; source path ; build pool 1/0
    $newpool = {
        name => 'openQA_disk',
        data => {
            type        => 'disk',
            target_path => '/dev/vda2',
            source_path => '/dev/vdb1',
            buildpool   => 'false',
        },
    };
    go_for_pool($newpool);

    # pool type fs: target path; source path
    $newpool = {
        name => 'openQA_fs',
        data => {
            type        => 'fs',
            target_path => '/var/lib/libvirt/images/openQA_fs',
            source_path => '/dev/vda2',
        },
    };
    go_for_pool($newpool);


    # pool type iscsi: target path (/dev/disk/by-path); hostname; source IQN; initiator IQN 1/0 -> value
    #    $newpool = {
    #    'name' => 'openQA_iscsi',
    #    'data' => {
    #        'type' => 'iscsi',
    #        'target_path' => '/dev/disk/by-path',
    #        'hostname' => 'localhost',
    #        'IQNsource' => 'IQNsource:iscsi',
    #        'initiator' => {
    #        'activate' => 'false',
    #        'name' => 'initiator',
    #        },
    #    },
    #    };
    #    go_for_pool($newpool);

    # pool logical: target path; source path ;  build pool 1/0
    $newpool = {
        name => 'openQA_logical',
        data => {
            type        => 'logical',
            target_path => '/dev/lvm0',
            source_path => '/data/testing',
            buildpool   => 'false',
        },
    };
    go_for_pool($newpool);

    # scsi: target path (dev/disk/by-path); source path (host0)
    $newpool = {
        name => 'openQA_scsi',
        data => {
            type        => 'scsi',
            target_path => '/dev/disk/by-path',
            source_path => 'host0',
        },
    };
    go_for_pool($newpool);

    my @tocheck = ('default', 'openQA_dir');
    checking_storage_result(\@tocheck);
}

1;


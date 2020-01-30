# SUSE's openQA tests
#
# Copyright (c) 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test ctdb resource agent
# Maintainer: Julien Adamek <jadamek@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;
use version_utils 'is_sle';
use utils qw(systemctl file_content_replace zypper_call);

sub run {
    # Exit of this module if we are in a maintenance update not related to samba
    return 1 if is_not_maintenance_update('samba');

    my $cluster_name = get_cluster_name;
    my $vip_ip       = '10.0.2.20';
    my $ctdb_folder  = '/srv/fs_cluster_md/ctdb';
    my $ctdb_timeout = bmwqemu::scale_timeout(60);

    # CTDB configuration must be done only in cluster nodes
    if (check_var('CTDB_TEST_ROLE', 'server')) {
        my $ctdb_cfg    = '/etc/samba/smb.conf';
        my $ctdb_socket = '/var/run/ctdb/ctdbd.socket';
        my $ctdb_rsc    = 'ctdb';
        my $nmb_rsc     = 'nmb';
        my $smb_rsc     = 'smb';
        my $ip_rsc      = 'vip';
        my @node_list;

        foreach my $node (1 .. get_node_number) {
            my $node_ip = get_ip(choose_node($node));
            push @node_list, $node_ip;
        }
        assert_script_run 'echo -e "' . join("\n", @node_list) . '" > /etc/ctdb/nodes';

        # Make sure samba is installed
        zypper_call 'in samba';

        # We need to check samba version because ctdb socket has changed for samba >= 4.10
        my $samba_version = script_output('rpm -q samba --qf \'%{VERSION}\'|awk -F "+" \'{print "v"$1}\'');
        $ctdb_socket = '/var/lib/ctdb/ctdb.socket' if (version->parse($samba_version) < version->parse(v4.10.0));

        # Make sure the services ctdb , smb , and nmb are disabled
        if (is_sle('15+')) {
            systemctl 'disable --now ctdb smb nmb';
        }
        else {
            systemctl 'disable ctdb smb nmb';
            systemctl 'stop ctdb smb nmb';
        }

        # Create ctdb folder
        assert_script_run "mkdir -p $ctdb_folder";

        # Get smb conf file from the openQA server
        assert_script_run "curl -f -v " . autoinst_url . "/data/ha/smb.conf -o $ctdb_cfg";
        file_content_replace("$ctdb_cfg", "%CTDB_SOCKET%" => "$ctdb_socket");

        if (is_node(1)) {
            # Set maintenance mode before adding resources
            assert_script_run "crm configure property maintenance-mode=true";

            # Create vip resource
            assert_script_run "EDITOR=\"sed -ie '\$ a primitive $ip_rsc IPaddr2 params ip='$vip_ip' nic='eth0' cidr_netmask='24' broadcast='10.0.2.255''\" crm configure edit";

            # Add ctdb, nmb, smb, group, clone and order resources
            assert_script_run "EDITOR=\"sed -ie '\$ a primitive $ctdb_rsc CTDB params ctdb_manages_winbind=false ctdb_manages_samba=false ctdb_recovery_lock='$ctdb_folder/ctdb.lock' ctdb_socket='$ctdb_socket''\" crm configure edit";
            assert_script_run "EDITOR=\"sed -ie '\$ a primitive $nmb_rsc systemd:nmb'\" crm configure edit";
            assert_script_run "EDITOR=\"sed -ie '\$ a primitive $smb_rsc systemd:smb'\" crm configure edit";
            assert_script_run "EDITOR=\"sed -ie '\$ a group ctdb-group $ctdb_rsc $nmb_rsc $smb_rsc'\" crm configure edit";
            assert_script_run "EDITOR=\"sed -ie '\$ a clone ctdb-clone ctdb-group meta interleave=true'\" crm configure edit";
            assert_script_run "EDITOR=\"sed -ie '\$ a colocation col-ctdb-with-clusterfs inf: ctdb-clone base-clone'\" crm configure edit";
            assert_script_run "EDITOR=\"sed -ie '\$ a colocation col-ip-with-ctdb Mandatory: $ip_rsc ctdb-clone'\" crm configure edit";
            assert_script_run "EDITOR=\"sed -ie '\$ a order o-clusterfs-then-ctdb Mandatory: base-clone ctdb-clone'\" crm configure edit";
            assert_script_run "EDITOR=\"sed -ie '\$ a order o-ip-then-ctdb Mandatory: $ip_rsc ctdb-clone'\" crm configure edit";

            # Remove maintenance mode and wait for resources start
            assert_script_run "crm configure property maintenance-mode=false";
            sleep 60;
            save_state;

            # Check CTDB status
            assert_script_run "ctdb status";

            # Add SMB password for root
            type_string "smbpasswd -a root ; echo smbpasswd-finished-\$? > /dev/$serialdev\n";
            assert_screen 'smbpasswd-password', $ctdb_timeout;
            type_password;
            send_key 'ret';
            assert_screen 'smbpasswd-confirm-password', $ctdb_timeout;
            type_password;
            send_key 'ret';
            wait_serial("smbpasswd-finished-0", $ctdb_timeout);
            save_screenshot;
        }
    }

    # Barrier to start tests from client
    barrier_wait("CTDB_INIT_$cluster_name");

    # Tests done by a client server
    if (check_var('CTDB_TEST_ROLE', 'client')) {
        # Mount the shared filesystem and test access
        type_string "mount -t cifs //$vip_ip/ctdb /mnt/ -o rw,user=root ; echo smbmount-finished-\$? > /dev/$serialdev\n";
        assert_screen 'smbmount-password', $ctdb_timeout;
        type_password;
        send_key 'ret';
        wait_serial("smbmount-finished-0", $ctdb_timeout);
        assert_script_run "cd /mnt; ls -altrh";
        save_screenshot;

        # Add files/data in the CIFS share
        assert_script_run "for i in \$(seq 1 5); do dd if=/dev/urandom of=file\${i} bs=1M count=10; md5sum file\${i} >> files.md5 ; done", $default_timeout;
    }

    # Synchronize all the nodes
    barrier_wait("CTDB_DONE_$cluster_name");

    # Check files consistency
    assert_script_run "cd $ctdb_folder; md5sum -c files.md5" if (is_node(1));
}

1;

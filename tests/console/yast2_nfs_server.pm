# SUSE's openQA tests
#
# Copyright © 2015-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add new yast2_nfs_server test
#    This tests "yast2 nfs-server" by creating an NFS share,
#    writing a file to it and validating that the file is accessible
#    after mounting.
#    It can also be used as a server in an "/ on NFS" test scenario.
#    In this case, NFSSERVER has to be 1, the server is accessible as
#    10.0.2.1 and it provides a mutex "nfs_ready".
# Maintainer: Fabian Vogt <fvogt@suse.com>

use strict;
use warnings;
use base "console_yasttest";
use utils;
use testapi;
use lockapi;
use mmapi;
use mm_network;

sub run {
    select_console 'root-console';

    if (get_var('NFSSERVER')) {
        # Configure static IP for client/server test
        configure_default_gateway;
        configure_static_ip('10.0.2.1/24');
        configure_static_dns(get_host_resolv_conf());
    }

    # Make sure packages are installed
    assert_script_run 'zypper -n in yast2-nfs-server';

    # Create a directory and place a test file in it
    assert_script_run 'mkdir /srv/nfs && echo mounted > /srv/nfs/file';

    type_string "yast2 nfs-server; echo YAST-DONE-\$?- > /dev/$serialdev\n";

    do {
        assert_screen([qw(nfs-server-not-installed nfs-firewall nfs-config)]);
        # install missing packages as proposed
        if (match_has_tag('nfs-server-not-installed') or match_has_tag('nfs-firewall')) {
            send_key 'alt-i';
        }
    } while (not match_has_tag('nfs-config'));

    # Start server
    send_key 'alt-s';
    send_key 'alt-n';

    assert_screen 'nfs-overview';

    # Add share
    send_key 'alt-d';
    assert_screen 'nfs-new-share';
    type_string '/srv/nfs';
    send_key 'alt-o';

    # Permissions dialog
    assert_screen 'nfs-share-host';
    send_key 'tab';
    # Change 'ro,root_squash' to 'rw,fsid=0,no_root_squash,...'
    send_key 'home';
    send_key 'delete';
    send_key 'delete';
    send_key 'delete';
    type_string "rw,fsid=0,no_";
    send_key 'alt-o';

    # Done
    assert_screen 'nfs-share-saved';
    send_key 'alt-f';
    wait_serial('YAST-DONE-0-') or die "'yast2 nfs-server' didn't finish";

    # Back on the console, test mount locally
    clear_console;

    validate_script_output "exportfs", sub { m,/srv/nfs, };
    if (get_var('NFSSERVER')) {
        assert_script_run 'mount 10.0.2.1:/ /mnt';
    }
    else {
        assert_script_run 'mount 10.0.2.15:/ /mnt';
    }

    # Timeout of 95 seconds to account for the NFS server grace period
    validate_script_output "cat /mnt/file", sub { m,mounted, }, 95;
    assert_script_run 'umount /mnt';

    if (get_var('NFSSERVER')) {
        # Server is up and running, client can use it now!
        mutex_create('nfs_ready');
        # Wait for the children (nfs clients) to finish
        wait_for_children;
    }
}

1;

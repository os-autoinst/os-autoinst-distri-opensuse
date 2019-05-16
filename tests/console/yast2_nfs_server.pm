# SUSE's openQA tests
#
# Copyright © 2015-2019 SUSE LLC
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

use base "y2_module_consoletest";
use utils qw(clear_console zypper_call);
use Utils::Systemd 'disable_and_stop_service';
use version_utils;
use testapi;
use lockapi;
use mmapi;
use mm_network;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    if (get_var('NFSSERVER')) {
        # Configure static IP for client/server test
        configure_default_gateway;
        configure_static_ip('10.0.2.101/24');
        configure_static_dns(get_host_resolv_conf());

        if (is_sle('15+')) {
            record_soft_failure 'boo#1130093 No firewalld service for nfs-kernel-server';
            disable_and_stop_service($self->firewall);
        }
    }

    # Make sure packages are installed
    zypper_call 'in yast2-nfs-server', timeout => 480, exitcode => [0, 106, 107];

    # Create a directory and place a test file in it
    assert_script_run 'mkdir /srv/nfs && echo success > /srv/nfs/file.txt';

    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'nfs-server');

    do {
        assert_screen([qw(nfs-server-not-installed nfs-firewall nfs-config)]);
        # install missing packages as proposed
        if (match_has_tag('nfs-server-not-installed') or match_has_tag('nfs-firewall')) {
            send_key 'alt-i';
        }
    } while (not match_has_tag('nfs-config'));

    # Start server
    send_key 'alt-s';

    if (is_sle('<15')) {
        send_key 'alt-f';    # Open port in firewall
        assert_screen 'nfs-firewall-open';
    }
    else {
        sleep 1;
        save_screenshot;
    }

    # Next step
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
    wait_serial("$module_name-0") or die "'yast2 nfs-server' didn't finish";

    # Back on the console, test mount locally
    clear_console;

    validate_script_output "exportfs", sub { m,/srv/nfs, };
    if (get_var('NFSSERVER')) {
        assert_script_run 'mount 10.0.2.101:/ /mnt';
    }
    else {
        assert_script_run 'mount 10.0.2.15:/ /mnt';
    }

    # Timeout of 95 seconds to account for the NFS server grace period
    validate_script_output "cat /mnt/file.txt", sub { m,success, }, 95;
    assert_script_run 'umount /mnt';

    if (get_var('NFSSERVER')) {
        # Server is up and running, client can use it now!
        mutex_create('nfs_ready');
        # Wait for the children (nfs clients) to finish
        wait_for_children;
    }
}

1;

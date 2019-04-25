# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast2_nfs_client module
#   Ensures that it works with the current version of nfs-client (it got broken
#   with the conversion from init.d to systemd services)
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "console_yasttest";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use mm_network;

sub run {
    #
    # Preparation
    #
    select_console 'root-console';
    if (get_var('NFSCLIENT')) {
        # Configure static IP for client/server test
        configure_default_gateway;
        configure_static_ip('10.0.2.102/24');
        configure_static_dns(get_host_resolv_conf());

        zypper_call('in yast2-nfs-client nfs-client', timeout => 360, exitcode => [0, 106, 107]);

        mutex_wait('nfs_ready');
        assert_script_run 'ping -c3 10.0.2.101';
    }
    else {
        # Make sure packages are installed
        zypper_call('in yast2-nfs-client nfs-client nfs-kernel-server', timeout => 180, exitcode => [0, 106, 107]);
        # Prepare the test file structure
        assert_script_run 'mkdir -p /tmp/nfs/server';
        assert_script_run 'echo "success" > /tmp/nfs/server/file.txt';
        # Serve the share
        assert_script_run 'echo "/tmp/nfs/server *(ro)" >> /etc/exports';
        systemctl 'start nfs-server';
    }
    # add comments into fstab and save current fstab bsc#429326
    assert_script_run 'sed -i \'5i# test comment\' /etc/fstab';
    assert_script_run 'cat /etc/fstab > fstab_before';

    #
    # YaST nfs-client execution
    #
    my $module_name = y2logsstep::yast2_console_exec(yast2_module => 'nfs-client');
    assert_screen 'yast2-nfs-client-shares';
    # Open the dialog to add a connection to the share
    send_key 'alt-a';
    assert_screen 'yast2-nfs-client-add';
    type_string get_var('NFSCLIENT') ? '10.0.2.101' : 'localhost';
    # Explore the available shares and select the only available one
    send_key 'alt-e';
    assert_screen 'yast2-nfs-client-exported';
    send_key 'alt-o';
    # Set the local mount point
    send_key 'alt-m';
    type_string '/tmp/nfs/client';
    sleep 1;
    save_screenshot;
    # Save the new connection and close YaST
    wait_screen_change { send_key 'alt-o' };
    wait_screen_change { send_key 'alt-o' };

    wait_serial("$module_name-0") or die "'yast2 nfs-server' didn't finish";

    clear_console;

    #
    # Check the result
    #

    # check if nfs is mounted
    script_run 'mount|grep nfs';
    script_run 'cat /etc/fstab|grep nfs';

    # Wait for more than 90 seconds due to NFSD's 90 second grace period.
    diag 'waiting 90 second due NFS grace period';
    sleep 90;

    # script_run is using bash return logic not perl logic, 0 is true
    if ((script_run 'grep "success" /tmp/nfs/client/file.txt') != 0) {
        record_soft_failure 'boo#1006815 nfs mount is not mounted';
        assert_script_run 'mount /tmp/nfs/client';
        assert_script_run 'grep "success" /tmp/nfs/client/file.txt';
    }

    # remove added nfs from /etc/fstab
    assert_script_run 'sed -i \'/nfs/d\' /etc/fstab';

    # compare saved and current fstab, should be same
    if ((script_run 'diff -b /etc/fstab fstab_before') != 0) {
        record_soft_failure 'bsc#429326 comments were deleted';
    }

    # compare last line, should be not deleted
    assert_script_run 'diff -b <(tail -n1 /etc/fstab) <(tail -n1 fstab_before)';
}

1;


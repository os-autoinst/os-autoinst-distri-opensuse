# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-nfs-client nfs-client
# Summary: yast2_nfs_client module
#   Ensures that it works with the current version of nfs-client (it got broken
#   with the conversion from init.d to systemd services)
#   This test expects version 3 of the NFS protocol
#   * The 2nd version is just enabled, checked and disabled
#   * The NFSv3 export is found and added using YaST
#   * We test mount and umount and we check for the version
#   * We try to read and write some forbiden files
#   * We download 1GB file and check it's checksum
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base "y2_module_consoletest";

use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use utils qw(zypper_call systemctl script_retry);
use mm_network 'setup_static_mm_network';
use nfs_common;

sub run {
    select_serial_terminal;

    # NFSCLIENT defines if the test should be run on multi-machine setup.
    # Otherwise, configure server and client on the single machine.
    if (get_var('NFSCLIENT')) {

        setup_static_mm_network('10.0.2.102/24');

        zypper_call('in yast2-nfs-client nfs-client', timeout => 480, exitcode => [0, 106, 107]);

        mutex_wait('nfs_ready');
        script_retry('ping -c3 10.0.2.101', delay => 15, retry => 12);
        assert_script_run "showmount -e 10.0.2.101";
    }
    else {
        # Make sure packages are installed
        zypper_call('in yast2-nfs-client nfs-client nfs-kernel-server', timeout => 480, exitcode => [0, 106, 107]);
        # Prepare the test file structure
        assert_script_run 'mkdir -p /tmp/nfs/server';
        assert_script_run 'echo "success" > /tmp/nfs/server/file.txt';
        # Serve the share
        assert_script_run 'echo "/tmp/nfs/server *(ro,fsid=23)" >> /etc/exports';
        systemctl 'start nfs-server';
        assert_script_run "showmount -e localhost";
    }
    # add comments into fstab and save current fstab bsc#429326
    assert_script_run 'sed -i \'5i# test comment\' /etc/fstab';
    assert_script_run 'cat /etc/fstab > fstab_before';

    # From now we need needles
    select_console 'root-console';

    #
    # YaST nfs-client execution
    #

    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'nfs-client');

    assert_screen 'yast2-nfs-client-shares', 60;
    send_key 'alt-a';
    assert_screen 'yast2-nfs-client-add';
    type_string get_var('NFSCLIENT') ? '10.0.2.101' : 'localhost';
    # Explore the available shares and select the only available one
    send_key 'alt-e';
    check_screen('yast2-nfs-client-exported', 15);
    if (not match_has_tag('yast2-nfs-client-exported')) {
        send_key 'down';
        assert_screen 'yast2-nfs-client-exported';
    }
    send_key 'alt-o';
    # Set the local mount point
    send_key 'alt-m';
    type_string '/tmp/nfs/client';
    sleep 1;
    save_screenshot;
    # Save the new connection and close YaST
    wait_screen_change { send_key 'alt-o' };
    sleep 1;
    save_screenshot;
    yast2_client_exit($module_name);

    #
    # Check the result
    #

    # From now we can use serial terminal
    select_serial_terminal;

    mount_export();
    if (get_var('NFSCLIENT')) {
        # Check NFS version
        assert_script_run "nfsstat -m | grep vers=3";

        client_common_tests();

        # Test NFSv3 POSIX permissions
        assert_script_run "ls -la /tmp/nfs/client/secret.txt | grep '\\-rwxr\\-\\-\\-\\-\\-'";
        assert_script_run "! sudo -u $testapi::username cat /tmp/nfs/client/secret.txt";

        # Test NFSv3 ro export
        assert_script_run "mkdir /tmp/nfs/ro";
        assert_script_run "mount 10.0.2.101:/srv/ro /tmp/nfs/ro";
        assert_script_run "ls /tmp/nfs/ro";
        assert_script_run "grep success /tmp/nfs/ro/file.txt";
        assert_script_run "! echo modified > /tmp/nfs/ro/file.txt";
        assert_script_run "! grep modified /tmp/nfs/ro/file.txt";

        # Safely umount NFS share
        assert_script_run 'umount /tmp/nfs/ro';
        assert_script_run 'umount /tmp/nfs/client';
    }
    else {
        # remove added nfs from /etc/fstab
        assert_script_run 'sed -i \'/nfs/d\' /etc/fstab';

        # compare saved and current fstab, should be same
        if ((script_run 'diff -b /etc/fstab fstab_before') != 0) {
            record_soft_failure 'bsc#429326 comments were deleted';
        }

        # compare last line, should be not deleted
        assert_script_run 'diff -b <(tail -n1 /etc/fstab) <(tail -n1 fstab_before)';
    }

}

1;


# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast2_nfs4_client module
#   This is the client side of yast2_nfs4_server module.
#   This uses the yast2 nfs-client module with NFS4 strictly enabled.
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "y2_module_consoletest";

use strict;
use warnings;
use utils qw(clear_console zypper_call systemctl);
use version_utils;
use testapi;
use lockapi;
use mm_network;
use nfs_common;

sub run {
    #
    # Preparation
    #
    select_console 'root-console';

    # Configure static IP for client/server test
    configure_default_gateway;
    configure_static_ip('10.0.2.102/24');
    configure_static_dns(get_host_resolv_conf());

    zypper_call('in yast2-nfs-client nfs-client nfs4-acl-tools', timeout => 480, exitcode => [0, 106, 107]);

    mutex_wait('nfs4_ready');
    assert_script_run 'ping -c3 10.0.2.101';

    # add comments into fstab and save current fstab bsc#429326
    assert_script_run 'sed -i \'5i# test comment\' /etc/fstab';
    assert_script_run 'cat /etc/fstab > fstab_before';

    #
    # YaST nfs-client execution
    #
    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'nfs-client');

    assert_screen 'yast2-nfs-client-shares';
    send_key 'alt-a';
    assert_screen 'yast2-nfs-client-add';
    # Enable NFSv4
    send_key 'alt-v';
    if (is_sle('15+')) {
        send_key 'down';
        send_key 'down';
        send_key 'ret';
    }
    # Type the nfs server hostname
    send_key 'alt-n';
    type_string '10.0.2.101';
    # Explore the available shares and select the only available one
    send_key 'alt-e';
    assert_screen 'yast2-nfs-client-exported';
    send_key 'alt-o';
    # Set the local mount point
    send_key 'alt-m';
    type_string '/tmp/nfs/client';
    sleep 1;
    save_screenshot;
    # Save the new connection and check it in table
    wait_screen_change { send_key 'alt-o' };
    sleep 1;
    save_screenshot;
    # Exit YaST
    wait_screen_change { send_key 'alt-o' };

    wait_serial("$module_name-0") or die "'yast2 $module_name' didn't finish";
    clear_console;

    mount_export();

    # Check NFS version
    assert_script_run "nfsstat -m | grep vers=4";

    client_common_tests();

    # Test NFSv4 POSIX permissions
    assert_script_run "ls -la /tmp/nfs/client/secret.txt | grep '\\-rwxr\\-\\-\\-\\-\\-'";
    assert_script_run "! sudo -u $testapi::username cat /tmp/nfs/client/secret.txt";

    # Test NFSv4 ACL
    assert_script_run "nfs4_getfacl /tmp/nfs/client/secret.txt";
    assert_script_run "nfs4_setfacl -R -a A:df:$testapi::username\@localdomain:RX /tmp/nfs/client/secret.txt";
    assert_script_run "nfs4_getfacl /tmp/nfs/client/secret.txt | grep \"A::`id -u $testapi::username`:rxtcy\"";
    assert_script_run "sudo -u $testapi::username cat /tmp/nfs/client/secret.txt";

    # Test NFSv4 ro export
    assert_script_run "mkdir /tmp/nfs/ro";
    assert_script_run "mount 10.0.2.101:/ro /tmp/nfs/ro";
    assert_script_run "ls /tmp/nfs/ro";
    assert_script_run "grep success /tmp/nfs/ro/file.txt";
    assert_script_run "echo modified > /tmp/nfs/ro/file.txt";
    assert_script_run "grep modified /tmp/nfs/ro/file.txt";

    # Safely umount NFS4 share
    assert_script_run 'umount /tmp/nfs/ro';
    assert_script_run 'umount /tmp/nfs/client';
}

1;


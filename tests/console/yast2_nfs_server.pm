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
#    10.0.2.101 and it provides a mutex "nfs_ready".
#    * We used YaST for configuring and creating this server
#    * We also create some testing files for the client
#    * The NFSv3 version is mounted and checked
# Maintainer: Fabian Vogt <fvogt@suse.com>

use strict;
use warnings;

use base "y2_module_consoletest";
use utils qw(clear_console zypper_call systemctl);
use version_utils;
use testapi;
use lockapi;
use mmapi;
use mm_network;
use nfs_common;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    my $rw     = '/srv/nfs';
    my $ro     = '/srv/ro';
    select_console 'root-console';

    if (get_var('NFSSERVER')) {
        server_configure_network($self);
    }

    # Make sure packages are installed
    zypper_call 'in yast2-nfs-server nfs-kernel-server', timeout => 480, exitcode => [0, 106, 107];

    try_nfsv2();

    prepare_exports($rw, $ro);

    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'nfs-server');

    yast2_server_initial();

    # Start server
    send_key 'alt-s';

    # Disable NFSv4
    send_key 'alt-v';
    wait_still_screen 1;

    yast_handle_firewall();

    # Next step
    send_key 'alt-n';

    assert_screen 'nfs-overview';

    add_shares($rw, $ro);

    send_key 'alt-f';
    wait_serial("$module_name-0") or die "'yast2 $module_name' didn't finish";

    # Back on the console, test mount locally
    clear_console;

    # Server is up and running, client can use it now!
    script_run "( journalctl -fu nfs-server > /dev/$serialdev & )";
    mutex_create('nfs_ready');
    check_nfs_ready($rw, $ro);

    if (get_var('NFSSERVER')) {
        assert_script_run "mount 10.0.2.101:${rw} /mnt";
    }
    else {
        assert_script_run "mount 10.0.2.15:${rw} /mnt";
    }

    # Timeout of 95 seconds to account for the NFS server grace period
    validate_script_output("cat /mnt/file.txt", sub { m,success, }, 95);

    # Check NFS version
    if (is_sle('=12-sp1') && script_run 'nfsstat -m') {
        record_soft_failure 'bsc#1140731';
    }
    else {
        validate_script_output "nfsstat -m", sub { m/vers=3/ };
    }

    assert_script_run 'umount /mnt';

    wait_for_children;
}

1;


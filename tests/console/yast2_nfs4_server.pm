# SUSE's openQA tests
#
# Copyright © 2015-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add new yast2_nfs4_server test
#    This tests "yast2 nfs-server" by creating an NFS share,
#    writing a file to it and validating that the file is accessible
#    after mounting.
#    It can also be used as a server in an "/ on NFS" test scenario.
#    the server is accessible as 10.0.2.101 and it provides a mutex "nfs4_ready".
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "y2_module_consoletest";

use strict;
use warnings;
use utils qw(clear_console zypper_call systemctl);
use version_utils;
use testapi;
use lockapi;
use mmapi;
use mm_network;
use nfs_common;

sub run {
    my ($self) = @_;
    my $rw     = '/srv/nfs';
    my $ro     = '/srv/nfs/ro';
    select_console 'root-console';

    server_configure_network($self);

    # Make sure packages are installed
    zypper_call 'in yast2-nfs-server', timeout => 480, exitcode => [0, 106, 107];

    try_nfsv2();

    prepare_exports($rw, $ro);

    my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'nfs-server');

    yast2_server_initial();

    # Start server
    send_key 'alt-s';
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
    script_run "( journalctl -fu nfsserver > /dev/$serialdev & )";
    mutex_create('nfs4_ready');
    check_nfs_ready($rw, $ro);

    assert_script_run 'mount -t nfs4 10.0.2.101:/ /mnt';

    # Timeout of 95 seconds to account for the NFS server grace period
    validate_script_output("cat /mnt/file.txt", sub { m,success, }, 95);

    # Check NFS version
    assert_script_run "nfsstat -m | grep vers=4";

    assert_script_run 'umount /mnt';

    # NFS4 Server is up and running, client can use it now!
    wait_for_children;
}

1;

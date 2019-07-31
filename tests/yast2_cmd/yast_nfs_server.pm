# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure nfs-server services in yast command line mode,
#          including add, delete, set and summary.
#
# Maintainer: Ming Li <mli@suse.com>

=head1 Create regression test for nfs-server and verify

Reference:
https://www.suse.com/documentation/sles-15/singlehtml/book_sle_admin/book_sle_admin.html#id-1.3.3.6.13.6.22
 
1. Start the nfs-server service.
2. Add a directory to export and used exportfs command verify.
3. Specifies additional parameters for the NFS server.
4. Displays a summary of the NFS server configuration.
5. Restore nfs-server settings and used summary parameter verify.
6. Delete the tmp directory for testing.
7. Stop the nfs-server service and verify the service status.
 
=cut

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils qw(systemctl zypper_call);

my $tmp_dir = "/my_nfs_tmp";
my $bsc_dir = "/test_nfs_server_bsc";

sub check_bsc1142979 {
    my $grep_cmd = script_run("grep -i $bsc_dir /etc/exports");
    if ($grep_cmd != 0) {
        my $ret_val = script_run("yast nfs-server delete mountpoint=$bsc_dir");
        if ($ret_val == 0) {
            record_soft_failure "Nfs-server bug: bsc#1142979 - Remove a mount directory that does not exist return value error"; }
    }
}

sub run {

    select_console("root-console");

    # Make sure nfs-server packages are installed
    zypper_call("in yast2-nfs-server nfs-kernel-server", exitcode => [0, 102, 103]);

    # 1. Start the nfs-server service
    assert_script_run("yast nfs-server start", fail_message => "yast nfs-server failed when starting nfs-server service");

    # 2. Add a directory to export and used exportfs command verify
    assert_script_run("yast nfs-server add mountpoint=$tmp_dir hosts=*.test.com");
    validate_script_output("exportfs", sub { m#$tmp_dir\s+\*.test.com# });

    # 3. Specifies additional parameters for the NFS server
    assert_script_run("yast nfs-server set enablev4=yes security=yes");

    # 4. Displays a summary of the NFS server configuration
    validate_script_output("yast nfs-server summary 2>&1",
        sub { m#NFS\s+server\s+is\s+enabled# && m#\*\s+$tmp_dir# && m#NFSv4\s+support\s+is\s+enabled# && m#NFS\s+Security\s+using\s+GSS\s+is\s+enabled#i });

    check_bsc1142979;

    # 5. Restore nfs-server settings and used summary parameter verify
    assert_script_run("yast nfs-server delete mountpoint=$tmp_dir");
    assert_script_run("yast nfs-server set enablev4=no security=no");
    validate_script_output("yast nfs-server summary 2>&1",
        sub { m#Not\s+configured\s+yet# && m#NFSv4\s+support\s+is\s+disabled# && m#NFS\s+Security\s+using\s+GSS\s+is\s+disabled#i });

    # 6. Delete the tmp directory for testing
    assert_script_run("rm -rf $tmp_dir", fail_message => "deleting $tmp_dir directory failed.");

    # 7. Stop the nfs-server service and verify the service status
    assert_script_run("yast nfs-server stop", fail_message => "yast nfs-server failed when stop nfs-server service");

    my $nfs_stop_status    = systemctl("is-active nfs-server",  ignore_failure => 1);
    my $nfs_enabled_status = systemctl("is-enabled nfs-server", ignore_failure => 1);
    if ($nfs_stop_status != 3 or $nfs_enabled_status != 1) {
        die "yast nfs-server failed to stop nfs-server service";
    }


}

1;

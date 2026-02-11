# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test NFS with krb5 authentication and GSS API - client
# Maintainer: QE Security <none@suse.de>
# Ticket: poo#51560, poo#52388

use base "consoletest";
use testapi;
use utils;
use lockapi;
use mmapi;
use krb5crypt;    # Import public variables
use version_utils 'is_sle';
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    assert_script_run("source /etc/profile.d/krb5.sh") if is_sle('<16');
    barrier_wait('KRB5_NFS_SERVER_READY');
    # Add principal for NFS service and add it to client's keytable
    assert_script_run "kadmin -p $adm -w $pass_a -q 'addprinc -randkey nfs/$dom_client'";
    assert_script_run "kadmin -p $adm -w $pass_a -q 'ktadd nfs/$dom_client'";
    systemctl("restart rpc-gssd.service");
    assert_script_run "mkdir -p $nfs_mntdir";

    # Test different sec options here:
    # sec=sys (no Kerberos use, we do not test it)
    # sec=krb5 (Kerberos user authentication only)
    # sec=krb5i (Kerberos user authentication and integrity checking)
    # sec=krb5p (Kerberos user authentication, integrity checking and NFS traffic encryption)
    for my $sec ('sys', 'krb5', 'krb5i', 'krb5p') {
        assert_script_run "mount -t nfs4 -o rw,sec=$sec $dom_server:$nfs_expdir $nfs_mntdir";
        assert_script_run "mount |grep $dom_server.*$sec";

        # Some simple operations with mounted directory
        assert_script_run "ls $nfs_mntdir/";
        assert_script_run "rm $nfs_mntdir/$nfs_fname", 150;    # Sometimes it takes long time.
        assert_script_run "touch $nfs_mntdir/$nfs_fname";
        assert_script_run "umount $nfs_mntdir";
    }
    barrier_wait('KRB5_NFS_TEST_DONE');
}

sub test_flags {
    return {fatal => 1};
}


1;

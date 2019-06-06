# Copyright © 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Test NFS with krb5 authentication and GSS API - client
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Ticket: poo#51560, poo#52388

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use mmapi;
use krb5crypt;    # Import public variables

sub run {
    select_console 'root-console';

    mutex_wait('CONFIG_READY_NFS_SERVER');

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

    mutex_create('TEST_DONE_NFS_CLIENT');
}

sub test_flags {
    return {always_rollback => 1};
}

1;

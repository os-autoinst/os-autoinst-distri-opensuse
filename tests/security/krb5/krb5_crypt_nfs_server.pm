# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test NFS with krb5 authentication and GSS API - server
# Maintainer: QE Security <none@suse.de>
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

    zypper_call("in nfs-kernel-server nfs-client");

    # Config NFS server
    foreach my $i ('NFS4_SUPPORT', 'NFS_SECURITY_GSS', 'NFS_GSSD_AVOID_DNS') {
        assert_script_run "sed -i 's/.*$i=.*\$/$i=\"yes\"/' /etc/sysconfig/nfs";
    }
    assert_script_run "cat /etc/sysconfig/nfs |& tee /dev/$serialdev";
    assert_script_run "mkdir -p $nfs_expdir && touch $nfs_expdir/$nfs_fname ";
    assert_script_run "chown -R 1000:100 $nfs_expdir";
    assert_script_run "echo '$nfs_expdir *(rw,sec=sys:krb5:krb5i:krb5p,no_subtree_check,all_squash,anonuid=1000,anongid=100,sync)' >> /etc/exports";

    # Add principal for NFS service and add it to server's keytable
    assert_script_run "kadmin -p $adm -w $pass_a -q 'addprinc -randkey nfs/$dom_server'";
    assert_script_run "kadmin -p $adm -w $pass_a -q 'ktadd nfs/$dom_server'";
    systemctl("restart rpc-svcgssd nfs-server");

    mutex_create('CONFIG_READY_NFS_SERVER');

    # Waiting for the finishd of krb5 client
    my $children = get_children();
    mutex_wait('TEST_DONE_NFS_CLIENT', (keys %$children)[0]);
    mutex_create('TEST_DONE_NFS_SERVER');
}

sub test_flags {
    return {always_rollback => 1};
}

1;

# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup KDC service for krb5 cryptographic testing
# Maintainer: QE Security <none@suse.de>
# Ticket: poo#51560, poo#51563

use base "consoletest";
use testapi;
use utils;
use lockapi;
use mmapi;
use krb5crypt;    # Import public variables
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    # Create KDC database
    validate_script_output "kdb5_util create -r $dom -s -P $pass_db", sub {
        m/
            Initializing\sdatabase.*for\srealm.*\Q$dom\E.*
            master\skey\sname.*\Q$dom\E.*/sxx
    };
    validate_script_output "kadmin.local -q listprincs", sub {
        m/krbtgt\/\Q$dom\E\@\Q$dom\E/;
    };

    # Add admin user
    assert_script_run "kadmin.local -q 'addprinc -pw $pass_a $adm'";
    validate_script_output "kadmin.local -q listprincs", sub {
        m/\Q$adm\E\@\Q$dom\E/;
    };

    systemctl("start krb5kdc");
    systemctl("enable krb5kdc");

    script_run("kinit $adm |& tee /dev/$serialdev", 0);
    wait_serial(qr/Password.*\Q$adm\E/) || die "Matching output failed";
    enter_cmd "$pass_a";
    script_output "echo \$?", sub { m/^0$/ };
    validate_script_output "klist", sub {
        m/
            Ticket\scache.*\/root\/kcache.*
            Default\sprincipal.*\Q$adm\E\@\Q$dom\E.*
            krbtgt\/\Q$dom\E\@\Q$dom\E.*
            renew\suntil.*/sxx
    };

    my $kadm_conf = '/var/lib/kerberos/krb5kdc/kadm5.acl';
    assert_script_run "sed -Ei 's/^#(.*\\/admin\@\Q$dom\E.*)/\\1/g' $kadm_conf";
    assert_script_run "cat $kadm_conf";

    systemctl("start kadmind");
    systemctl("enable kadmind");

    barrier_wait('KRB5_KDC_READY');

    # Waiting for the finish of krb5 SSH tests
    barrier_wait('KRB5_SSH_TEST_DONE');
    # Waiting for the finish of krb5 NFS tests
    barrier_wait('KRB5_NFS_TEST_DONE');
    # Wait a bit to ensure the barrier is released before the job finishes
    sleep 5;
}

sub test_flags {
    return {fatal => 1};
}

1;

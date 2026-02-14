# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test ssh with krb5 authentication - client
# Maintainer: QE Security <none@suse.de>
# Ticket: poo#51560, poo#51569

use base "consoletest";
use testapi;
use utils;
use lockapi;
use mmapi;
use version_utils 'is_sle';
use krb5crypt;    # Import public variables
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    barrier_wait('KRB5_SSH_SERVER_READY');

    script_run("kinit -p $tst |& tee /dev/$serialdev", 0);
    wait_serial(qr/Password.*$tst/) || die "Matching output failed";
    enter_cmd "$pass_t";
    script_output "echo \$?", sub { m/^0$/ };
    validate_script_output "klist", sub {
        m/Default principal.*$tst/;
    };

    # Try connecting to server
    # -K Enables GSSAPI-based authentication and forwarding (delegation)
    # of GSSAPI credentials to the server

    # Debugging GSSAPI: Check DNS, ticket cache encryption types, and service ticket availability
    script_run "getent hosts $dom_server |& tee /dev/$serialdev";
    script_run "klist -e |& tee /dev/$serialdev";
    script_run "kvno host/$dom_server |& tee /dev/$serialdev";
    validate_script_output "ssh -p 2222 -K -vvv -o StrictHostKeyChecking=no -o PasswordAuthentication=no $tst\@$dom_server hostname 2>&1",
      sub { m/krb5server/ };
    # ensure the hostname is not changed after ssh connection
    validate_script_output "hostname", sub { m/krb5client/ };
    barrier_wait('KRB5_SSH_TEST_DONE');
}

sub test_flags {
    return {fatal => 1};
}

1;

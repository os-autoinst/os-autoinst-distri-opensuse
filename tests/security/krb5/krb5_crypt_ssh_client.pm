# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test ssh with krb5 authentication - client
# Maintainer: QE Security <none@suse.de>
# Ticket: poo#51560, poo#51569

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

    foreach my $i ('GSSAPIAuthentication', 'GSSAPIDelegateCredentials') {
        assert_script_run "sed -i 's/^.*$i .*\$/$i yes/' /etc/ssh/ssh_config";
    }

    mutex_wait('CONFIG_READY_SSH_SERVER');

    script_run("kinit -p $tst |& tee /dev/$serialdev", 0);
    wait_serial(qr/Password.*$tst/) || die "Matching output failed";
    enter_cmd "$pass_t";
    script_output "echo \$?", sub { m/^0$/ };
    validate_script_output "klist", sub {
        m/Default principal.*$tst/;
    };

    # Try connecting to server
    my $ssherr = "ssh login failed";
    script_run("ssh -v -o StrictHostKeyChecking=no $tst\@$dom_server |& tee /dev/$serialdev", 0);
    wait_serial "$tst\@.*~>" || die $ssherr;
    validate_script_output "hostname", sub { m/krb5server/ };

    # Exit the server
    send_key 'ctrl-d';
    validate_script_output "hostname", sub { m/krb5client/ };

    mutex_create('TEST_DONE_SSH_CLIENT');
}

sub test_flags {
    return {always_rollback => 1};
}

1;

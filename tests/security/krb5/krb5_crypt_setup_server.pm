# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup server machine for krb5 cryptographic testing
# Maintainer: QE Security <none@suse.de>
# Ticket: poo#51560, poo#51566

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

    mutex_wait('CONFIG_READY_KRB5_KDC');
    krb5_init;

    # Add secret key in keytab file
    assert_script_run "kadmin -p $adm -w $pass_a -q 'addprinc -randkey host/$dom_server'";
    assert_script_run "kadmin -p $adm -w $pass_a -q 'ktadd host/$dom_server'";
    mutex_create('CONFIG_READY_KRB5_SERVER');

    # Waiting for the finishd of krb5 client
    my $children = get_children();
    mutex_wait('TEST_DONE_CLIENT', (keys %$children)[0]);
    mutex_create('TEST_DONE_SERVER');
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;

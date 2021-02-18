# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: smt SUSEConnect
# Summary: run smt server, check client registration
# - Run basic smt commands
# - Wait for client registraton
# - Check client registration
# Maintainer: Katerina Lorenzova <klorenzova@suse.cz>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use lockapi;

sub run {
    select_console 'root-console';

    # check and start mariadb.service if it stopped. It stops sometimes and 'smt-repos' has then issue with connection
    if ((script_run('systemctl is-active mariadb.service')) != 0) {
        record_info 'stopped', 'mariadb is stopped';
        systemctl 'start mariadb.service';
    }

    assert_script_run 'smt-repos -m';
    validate_script_output 'SUSEConnect --status', sub { m/"identifier":"SLES","version":"12\.5","arch":"x86_64","status":"Registered"/ };
    validate_script_output 'smt-repos -o',         sub { m/SLES12-SP5-Updates/ };

    barrier_wait 'smt_setup';

    #time for registration of clients

    barrier_wait 'smt_registered';
    validate_script_output 'smt-list-registrations', sub { m/client1/ };
    assert_script_run 'smt-job -l';
}
1;

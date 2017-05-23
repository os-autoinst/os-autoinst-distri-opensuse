# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Postgres tests for SLE12
# Maintainer:  Ondřej Súkup <osukup@suse.cz>

use base "consoletest";
use strict;
use testapi;
use utils;
use apachetest;

sub run() {
    select_console 'root-console';

    # install the postgresql94 server package
    zypper_call "in postgresql94-server sudo";

    # start the postgresql94 service
    assert_script_run "systemctl start postgresql.service", 200;

    # check the status
    assert_script_run "systemctl show -p ActiveState postgresql.service | grep ActiveState=active";

    if (check_var('VERSION', '12')) {    # loaded via init.d on SLES 12 GA
        assert_script_run "systemctl show -p SubState postgresql.service | grep SubState=exited";
    }
    else {
        assert_script_run "systemctl show -p SubState postgresql.service | grep SubState=running";
    }

    # test basic functionality of postgresql94
    setup_pgsqldb;
    destroy_pgsqldb;
}

1;

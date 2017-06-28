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

    # install the postgresql server package
    zypper_call 'in postgresql96-server sudo';

    # start the postgresql service
    assert_script_run 'systemctl start postgresql.service', 200;

    # check the status
    assert_script_run 'systemctl show -p ActiveState postgresql.service | grep ActiveState=active';
    assert_script_run 'systemctl show -p SubState postgresql.service | grep SubState=running';

    # test basic functionality of postgresql
    setup_pgsqldb;
    destroy_pgsqldb;
}

1;
# vim: set sw=4 et:

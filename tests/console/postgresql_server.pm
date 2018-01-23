# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Postgres tests
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use base "consoletest";
use strict;
use testapi;
use utils;
use version_utils 'sle_version_at_least';
use apachetest;

sub run {
    select_console 'root-console';

    my $pgsql_server = sle_version_at_least('15') ? 'postgresql10-server' : 'postgresql96-server';
    # install the postgresql server package
    zypper_call "in $pgsql_server sudo";

    # start the postgresql service
    systemctl 'start postgresql.service', timeout => 200;

    # check the status
    systemctl 'show -p ActiveState postgresql.service | grep ActiveState=active';
    systemctl 'show -p SubState postgresql.service | grep SubState=running';

    # test basic functionality of postgresql
    setup_pgsqldb;
    destroy_pgsqldb;
}

1;
# vim: set sw=4 et:

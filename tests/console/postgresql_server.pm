# SUSE's openQA tests
#
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Postgres tests
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use apachetest;

sub run {
    select_console 'root-console';

    # install the postgresql server package
    zypper_call "in postgresql-server sudo";

    # start the postgresql service
    systemctl 'start postgresql.service', timeout => 200;

    # check the status
    systemctl 'show -p ActiveState postgresql.service | grep ActiveState=active';
    systemctl 'show -p SubState postgresql.service | grep SubState=running';

    # test basic functionality of postgresql
    setup_pgsqldb;
    destroy_pgsqldb;
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    $self->SUPER::post_fail_hook;
    upload_logs('/var/lib/pgsql/initlog');
    # this might fail to find any files so conduct as last step
    assert_script_run('tar -capf /tmp/pg_log.tar.xz /var/lib/pgsql/data/pg_log/*');
    upload_logs('/tmp/pg_log.tar.xz');
}

1;

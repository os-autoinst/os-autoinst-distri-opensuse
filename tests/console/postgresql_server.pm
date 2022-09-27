# SUSE's openQA tests
#
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: postgresql-server sudo
# Summary: Postgres tests
# - Install postgresql-server sudo
# - Start postgresql service
# - Check if postgresql was started and is running
# - Populate postgresql with test db from data dir
# - Run a select command
# - Drop postgresql database
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use apachetest qw(setup_pgsqldb destroy_pgsqldb test_pgsql postgresql_cleanup);
use Utils::Systemd 'systemctl';
use version_utils qw(is_transactional);
use transactional qw(trup_call check_reboot_changes);

sub run {
    my $self = shift;
    # install the postgresql server package
    if (is_transactional) {
        select_console 'root-console';
        trup_call("pkg install postgresql-server sudo");
        check_reboot_changes;
    } else {
        $self->select_serial_terminal;
        zypper_call "in postgresql-server sudo";
    }

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

# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Postgres tests for 11SP4
# G-Maintainer: Richard Brown <rbrownccb@opensuse.org>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;

    select_console 'root-console';

    # install the postgresql94 server package
    zypper_call "in postgresql94-server";

    # start the postgresql94 service
    assert_script_run "systemctl start postgresql.service", 200;

    # check the status
    assert_script_run "systemctl show -p ActiveState postgresql.service | grep ActiveState=active";
    assert_script_run "systemctl show -p SubState postgresql.service | grep SubState=running";

    # test basic functionality - require postgresql94
    assert_script_run "sudo -u postgres createdb openQAdb";
    assert_script_run "sudo -u postgres psql -d openQAdb -c \"CREATE TABLE test (id SERIAL PRIMARY KEY, entry VARCHAR)\"";
    assert_script_run "sudo -u postgres psql -d openQAdb -c \"INSERT INTO test (entry) VALUES ('openQA_test'), ('can you read this?');\"";
    assert_script_run "sudo -u postgres psql -d openQAdb -c \"SELECT * FROM test\" | grep \"can you read this\"";
}

1;

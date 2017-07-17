# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: PHP7 code that interacts locally with PostgreSQL
#   This tests creates a PostgreSQL database and inserts an element.
#   Then, PHP reads the elements and writes a new one in the database.
#   If all succeed, the test passes.
#
#   The test requires the Web and Scripting module on SLE
# Maintainer: Ondřej Súkup <osukup@suse.cz>


use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use apachetest;

sub run {
    select_console 'root-console';

    # ensure apache2 + php7 installed and running
    setup_apache2(mode => 'PHP7');

    # install requirements
    zypper_call 'in php7-pgsql postgresql96-server sudo';

    # start postgresql service
    assert_script_run 'systemctl start postgresql';

    # setup database
    setup_pgsqldb;

    # test itself
    test_pgsql;

    # destroy database
    destroy_pgsqldb;
}
1;

# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
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
# - Setup apache2 to use php7 modules
# - Install php7-pgsql postgresql*-contrib sudo
# - Start postgresql service
# - Populate postgresql with test db from data dir
# - Run a select command
# - Setup postgresql (password, access control)
# - Grab php test file from datadir
# - Run "curl --no-buffer http://localhost/test_postgresql_connector.php | grep 'can you read this?'"
# - Run select on database to check inclusion
# - Set PG_OLDEST, PG_LATEST and run a set of tests
#   - Create a new database
#   - Start/Stop/Status a database
#   - Upgrade a postgresql instance
#   - Cleanup database
# - Import and run dvdrental test
# - Cleanup postgresql database
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

    # install requirements, all postgresql versions to test db upgrade if there are multiple versions
    zypper_call 'in php7-pgsql postgresql*-contrib sudo';

    # start postgresql service
    systemctl 'start postgresql';

    # setup database
    setup_pgsqldb;

    # test itself
    test_pgsql;

    # destroy database
    destroy_pgsqldb;
}
1;

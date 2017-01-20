# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: PHP5 code that interacts locally with PostgreSQL
#   This tests creates a PostgreSQL database and inserts an element.
#   Then, PHP reads the elements and writes a new one in the database.
#   If all succeed, the test passes.
#
#   The test requires the Web and Scripting module on SLE and should be
#   executed after the 'console/http_srv', 'console/postgresql94', and
#   'console/php5' tests.
# Maintainer: Romanos Dodopoulos <romanos.dodopoulos@suse.cz>


use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run() {
    select_console 'root-console';

    # install requirements
    zypper_call "in php5-pgsql";

    # configuration so that PHP can access PostgreSQL
    # setup password
    type_string "sudo -u postgres psql postgres\n";
    type_string "\\password postgres\n";
    type_string "postgres\n";
    type_string "postgres\n";
    type_string "\\q\n";
    # comment out default configuration
    assert_script_run "sed -i 's/^host/#host/g' /var/lib/pgsql/data/pg_hba.conf";
    # allow postgres to access the db with password authentication
    assert_script_run "echo 'host openQAdb postgres 127.0.0.1/32 password' >> /var/lib/pgsql/data/pg_hba.conf";
    assert_script_run "echo 'host openQAdb postgres      ::1/128 password' >> /var/lib/pgsql/data/pg_hba.conf";
    assert_script_run "systemctl restart postgresql.service";

    # configure the PHP code that:
    #  1. reads table 'test' from the 'openQAdb' database (created in 'console/postgresql94' test)
    #  2. inserts a new element 'can php write this?' into the same table
    type_string "wget --quiet "
      . data_url('console/test_postgresql_connector.php')
      . " -O /srv/www/htdocs/test_postgresql_connector.php\n";
    assert_script_run "systemctl restart apache2.service";

    # access the website and verify that it can read the database
    assert_script_run "curl --no-buffer http://localhost/test_postgresql_connector.php | grep 'can you read this?'";

    # verify that PHP successfully wrote the element in the database
    assert_script_run "sudo -u postgres psql -d openQAdb -c \"SELECT * FROM test\" | grep 'can php write this?'";
}
1;

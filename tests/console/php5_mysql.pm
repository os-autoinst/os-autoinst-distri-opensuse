# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: PHP5 code that interacts locally with MySQL
#   This tests creates a MySQL database and inserts an element. Then,
#   PHP reads the elements and writes a new one in the database. If
#   all succeed, the test passes.
#
#   The test requires the Web and Scripting module on SLE
# Maintainer: Ondřej Súkup <osukup@suse.cz>


use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use apachetest;

sub run() {
    select_console 'root-console';

    setup_apache2(mode => 'PHP5');
    # install requirements
    zypper_call "in php5-mysql";

    # create the 'openQAdb' database with table 'test' and insert one element 'can php read this?'
    assert_script_run
qq{mysql -u root -e "CREATE DATABASE openQAdb; USE openQAdb; CREATE TABLE test (id int NOT NULL AUTO_INCREMENT, entry varchar(255) NOT NULL, PRIMARY KEY(id)); INSERT INTO test (entry) VALUE ('can you read this?');"};

    # configure the PHP code that:
    #  1. reads table 'test' from the 'openQAdb' database
    #  2. inserts a new element 'can php write this?' into the same table
    assert_script_run "wget --quiet " . data_url('console/test_mysql_connector.php') . " -O /srv/www/htdocs/test_mysql_connector.php";
    assert_script_run "systemctl restart apache2.service";

    # access the website and verify that it can read the database
    assert_script_run "curl --no-buffer http://localhost/test_mysql_connector.php | grep 'can you read this?'";

    # verify that PHP successfully wrote the element in the database
    assert_script_run "mysql -u root -e 'USE openQAdb; SELECT * FROM test;' | grep 'can php write this?'";
}
1;

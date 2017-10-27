# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test that uses isql command line tool to interact with unixODBC
# plugin
# This test consists on a MySQL/MariaDB database and a unixODBC plugin. It
# first inserts an element. Then uses isql to read the elements.
# If succeed, the test passes, proving that the connection is working.
#
# Maintainer: Ednilson Miura <emiura@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub setup {
    # write odbc.ini
    assert_script_run "echo [myodbc_mysql_dsn] > /etc/unixODBC/odbc.ini";
    assert_script_run "echo Description=description of your DSN >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Driver=myodbc_mysql >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Server=localhost >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Port=3306 >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Socket=/var/run/mysql/mysql.sock >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Database=odbcTEST >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Option=3 >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo ReadOnly=No >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo User=root >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Password=x >> /etc/unixODBC/odbc.ini";

    # write odbcinst.ini
    assert_script_run "echo [myodbc_mysql] > /etc/unixODBC/odbcinst.ini";
    assert_script_run "echo Description=ODBC for MySQL >> /etc/unixODBC/odbcinst.ini";
    assert_script_run 'echo Driver=$(rpm --eval "%_libdir")/libmyodbc5.so >> /etc/unixODBC/odbcinst.ini';
    assert_script_run 'echo Setup=$(rpm --eval "%_libdir")/libodbcmyS.so >> /etc/unixODBC/odbcinst.ini';
    assert_script_run "echo UsageCount=2 >> /etc/unixODBC/odbcinst.ini";

    # create the 'odbcTEST' database with table 'test' and insert one element
    assert_script_run qq{mysql -u root -e "CREATE DATABASE odbcTEST; USE odbcTEST; CREATE TABLE test
(id int NOT NULL AUTO_INCREMENT, entry varchar(255) NOT NULL, PRIMARY KEY(id));
INSERT INTO test (entry) VALUE ('can you read this?');"};
    # changes mysql password temporarly to "x" becase 'isql' does not support
    # blank password
    assert_script_run qq{mysqladmin -u root password x};

    # write a simple sql query to test connectivity
    assert_script_run qq{echo "SELECT * FROM test;" > query.sql};
}

sub run {
    select_console 'root-console';

    # install requirements
    zypper_call 'in mysql mariadb-client sudo MyODBC-unixODBC';

    # restart mysql server
    systemctl "restart mysql";

    # setup config files
    setup;

    # install odbc driver
    assert_script_run 'odbcinst -i -d -f /etc/unixODBC/odbcinst.ini';

    # install DSN
    assert_script_run 'odbcinst -i -s -l -f /etc/unixODBC/odbc.ini';

    # check odbcinst
    assert_script_run 'odbcinst -s -q';

    # connect to odbc
    assert_script_run 'isql myodbc_mysql_dsn root x -b < query.sql';
    assert_screen 'mysql_odbc-isql';

    # reverting mysql password to blank, else other mysql tests fail
    assert_script_run qq{mysqladmin -u root -px password ''};
}

1;

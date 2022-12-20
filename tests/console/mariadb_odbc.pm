# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: mysql mariadb-client sudo mariadb-connector-odbc unixODBC MyODBC-unixODBC
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
use version_utils qw(is_sle is_leap);

sub setup {
    # write odbc.ini
    assert_script_run "echo [mariadbodbc_mysql_dsn] > /etc/unixODBC/odbc.ini";
    assert_script_run "echo Description=description of your DSN >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Driver=mariadbodbc_mysql >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Server=localhost >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Port=3306 >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Socket=/var/run/mysql/mysql.sock >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Database=odbcTEST >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Option=3 >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo ReadOnly=No >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo User=root >> /etc/unixODBC/odbc.ini";
    assert_script_run "echo Password=x >> /etc/unixODBC/odbc.ini";

    # write odbcinst.ini
    assert_script_run "echo [mariadbodbc_mysql] > /etc/unixODBC/odbcinst.ini";
    assert_script_run "echo Description=ODBC for MySQL >> /etc/unixODBC/odbcinst.ini";

    if (is_sle('<15') || is_leap('<15.0')) {
        assert_script_run 'echo Driver=$(rpm --eval "%_libdir")/libmyodbc5.so >> /etc/unixODBC/odbcinst.ini';
    } else {
        assert_script_run 'echo Driver=$(rpm -ql mariadb-connector-odbc | grep -E libmaodbc.so\$) >> /etc/unixODBC/odbcinst.ini';
    }

    assert_script_run 'echo Setup=$(rpm --eval "%_libdir")/unixODBC/libodbcmyS.so >> /etc/unixODBC/odbcinst.ini';
    assert_script_run "echo UsageCount=2 >> /etc/unixODBC/odbcinst.ini";

    # create the 'odbcTEST' database with table 'test' and insert one element
    assert_script_run qq{mariadb -u root -e "CREATE DATABASE odbcTEST; USE odbcTEST; CREATE TABLE test
(id int NOT NULL AUTO_INCREMENT, entry varchar(255) NOT NULL, PRIMARY KEY(id));
INSERT INTO test (entry) VALUE ('can you read this?');"};
    # changes mysql password temporarily to "x" because 'isql' does not support
    # blank password
    assert_script_run qq{mariadb-admin -u root password x};

    # write a simple sql query to test connectivity
    assert_script_run qq{echo "SELECT * FROM test;" > query.sql};
}

sub run {
    select_console 'root-console';

    # install requirements
    my $odbc = (!is_sle('<15') && !is_leap('<15.0')) ? 'mariadb-connector-odbc unixODBC' : 'MyODBC-unixODBC';
    zypper_call 'in mariadb mariadb-client sudo ' . $odbc;

    # restart mariadb server
    systemctl "restart mariadb";

    # setup config files
    setup;

    # install odbc driver
    assert_script_run 'odbcinst -i -d -f /etc/unixODBC/odbcinst.ini';

    # install DSN
    assert_script_run 'odbcinst -i -s -l -f /etc/unixODBC/odbc.ini';

    # check odbcinst
    assert_script_run 'odbcinst -s -q';

    # connect to odbc
    assert_script_run 'isql mariadbodbc_mysql_dsn root x -b -v < query.sql';
    assert_screen 'mysql_odbc-isql';

    # reverting mysql password to blank, else other mysql tests fail
    assert_script_run qq{mariadb-admin -u root -px password ''};
}

1;

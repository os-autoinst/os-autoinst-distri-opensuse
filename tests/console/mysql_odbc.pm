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
# Maintainer: Ednilson Miura <emiura@suse.cz>


use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub write_odbc{
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
}

sub write_odbcinst{
     assert_script_run "echo [myodbc_mysql] > /etc/unixODBC/odbcinst.ini";
     assert_script_run "echo Description=ODBC for MySQL >> /etc/unixODBC/odbcinst.ini";
     assert_script_run "echo Driver=/usr/lib64/libmyodbc5.so >> /etc/unixODBC/odbcinst.ini";
     assert_script_run "echo Setup=/usr/lib64/unixODBC/libodbcmyS.so >> /etc/unixODBC/odbcinst.ini";
     assert_script_run "echo UsageCount=2 >> /etc/unixODBC/odbcinst.ini";
}

sub setup_mysql {
    # create the 'odbcTEST' database with table 'test' and insert one element
    assert_script_run qq{mysql -u root -e "CREATE DATABASE odbcTEST; USE odbcTEST; CREATE TABLE test
(id int NOT NULL AUTO_INCREMENT, entry varchar(255) NOT NULL, PRIMARY KEY(id));
INSERT INTO test (entry) VALUE ('can you read this?');"};
    assert_script_run qq{mysqladmin -u root password x};

    # unable to run isql with blank password
    assert_script_run qq{echo "SELECT * FROM test;" > query.sql};
}


sub run {
    select_console 'root-console';

    # install requirements
    zypper_call 'in mysql mariadb-client sudo MyODBC-unixODBC';
    write_odbc;
    write_odbcinst;

    # install odbc driver
    assert_script_run 'odbcinst -i -d -f /etc/unixODBC/odbcinst.ini';

    # install DSN
    assert_script_run 'odbcinst -i -s -l -f /etc/unixODBC/odbc.ini';

    # print config file
    assert_script_run 'cat /etc/unixODBC/odbc.ini';
    assert_script_run 'cat /etc/unixODBC/odbcinst.ini';
    assert_script_run 'systemctl restart mysql', 300;

    # setup mysql
    setup_mysql;

    assert_script_run 'ls -la';
    assert_script_run 'cat query.sql';

    # check odbcinst
    assert_script_run 'odbcinst -s -q';

    # connect to odbc
    assert_script_run 'isql myodbc_mysql_dsn root x -b < query.sql';
    assert_screen 'isql';

    # reverting mysql password to blank
    assert_script_run qq{mysqladmin -u root -px password ''};

 
}

1;

# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: PHP7 code that interacts locally with MySQL
#   This tests creates a MySQL database and inserts an element. Then,
#   PHP reads the elements and writes a new one in the database. If
#   all succeed, the test passes.
#
#   The test requires the Web and Scripting module on SLE
# - Setup apache to use php7 modules
# - Install php7-mysql mysql sud
# - Restart mysql service
# - Create a test database
# - Insert a element "can you read this?"
# - Grab a php test file from datadir, test it with curl in apache
# - Run select manually to check for the element
# - Drop created database
# Maintainer: Ondřej Súkup <osukup@suse.cz>


use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use apachetest;

sub run {
    select_console 'root-console';

    setup_apache2(mode => 'PHP7');
    # install requirements
    zypper_call "in php7-mysql mysql sudo";

    systemctl 'restart mysql', timeout => 300;

    test_mysql;
}
1;

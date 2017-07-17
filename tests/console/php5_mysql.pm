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

sub run {
    select_console 'root-console';

    setup_apache2(mode => 'PHP5');
    # install requirements
    zypper_call "in php5-mysql mysql sudo";

    assert_script_run "systemctl restart mysql", 300;

    test_mysql;
}

1;

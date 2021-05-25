# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: mariadb
# Summary: simple mariadb server startup test
# - Install mariadb
# - Check mariadb service status
# - Start mariadb
# - Check mariadb service status
# Maintainer: QE Core <qe-core@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    zypper_call('in mariadb');
    my $mariadb = (is_sle '<15-SP4') ? 'mysql' : 'mariadb';
    if (script_run("grep 'bindir=\"\$basedir/sbin\"' /usr/bin/${mariadb}_install_db") == 0) {
        record_soft_failure 'bsc#1142058';
        assert_script_run "sed -i 's|resolveip=\"\$bindir/resolveip\"|resolveip=\"/usr/bin/resolveip\"|' /usr/bin/${mariadb}_install_db";
    }
    systemctl "status $mariadb", expect_false => 1, fail_message => 'mariadb should be disabled by default';
    systemctl "start $mariadb";
    systemctl "status $mariadb";
    assert_screen 'test-mysql_srv-1';
}

1;

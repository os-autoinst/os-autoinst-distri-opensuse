# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle);
use Utils::Architectures;

sub cleanup {
    systemctl 'stop mariadb';
    systemctl 'stop mariadb@node1.service';
    systemctl 'stop mariadb@node2.service';
}

sub run {
    select_serial_terminal;

    zypper_call('in mariadb');
    my $mariadb = (is_sle '<15-SP4') ? 'mysql' : 'mariadb';
    if (script_run("grep 'bindir=\"\$basedir/sbin\"' /usr/bin/${mariadb}_install_db") == 0) {
        record_soft_failure 'bsc#1142058';
        assert_script_run "sed -i 's|resolveip=\"\$bindir/resolveip\"|resolveip=\"/usr/bin/resolveip\"|' /usr/bin/${mariadb}_install_db";
    }
    systemctl "status $mariadb", expect_false => 1, fail_message => 'mariadb should be disabled by default';
    systemctl "start $mariadb", timeout => 300;
    systemctl "is-active $mariadb";

    # Test multiple instance configuration
    # It is not supported in sle12sp2 and sle12sp3
    if (!is_sle('<=12-SP3')) {
        assert_script_run "touch /etc/mynode{1,2}.cnf";
        assert_script_run "curl " . data_url('console/mariadb/mynode1.cnf') . " -o /etc/mynode1.cnf";
        assert_script_run "curl " . data_url('console/mariadb/mynode2.cnf') . " -o /etc/mynode2.cnf";
        assert_script_run "mkdir -p /var/lib/mysql/node{1,2}";
        assert_script_run "chown mysql:root /var/lib/mysql/node{1,2}";

        # Start the two instances
        systemctl 'start mariadb@node1.service';
        systemctl 'start mariadb@node2.service';

        # Test a regression for broken multi instance
        assert_script_run '/usr/bin/my_print_defaults --defaults-extra-file=/etc/mynode1.cnf mysqld mysqld_multi "node1" | grep datadir';

        # Stop the two instances
        cleanup();
    }
}

sub post_fail_hook {
    my ($self) = @_;
    cleanup();
    $self->SUPER::post_fail_hook;
}
1;

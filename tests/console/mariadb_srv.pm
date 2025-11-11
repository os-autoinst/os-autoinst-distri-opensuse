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

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_jeos has_selinux is_public_cloud);
use Utils::Architectures;

my $mariadb = (is_sle '<15-SP4') ? 'mysql' : 'mariadb';
my $db = 'test_mariadb';

sub cleanup {
    script_run("$mariadb -u root -e 'DROP DATABASE IF EXISTS $db'");
    systemctl "stop $mariadb";
    systemctl 'stop mariadb@node1.service';
    systemctl 'stop mariadb@node2.service';
}

sub run {
    select_serial_terminal;

    zypper_call('in mariadb');
    zypper_call("in policycoreutils-python-utils") if has_selinux();

    if (script_run("grep 'bindir=\"\$basedir/sbin\"' /usr/bin/${mariadb}_install_db") == 0) {
        record_soft_failure 'bsc#1142058';
        assert_script_run "sed -i 's|resolveip=\"\$bindir/resolveip\"|resolveip=\"/usr/bin/resolveip\"|' /usr/bin/${mariadb}_install_db";
    }

    if (has_selinux()) {
        assert_script_run("semanage port -a -t mysqld_port_t -p tcp 3310");
        assert_script_run("semanage port -a -t mysqld_port_t -p tcp 3315");
    }

    systemctl "status $mariadb", expect_false => 1, fail_message => 'mariadb should be disabled by default' unless is_public_cloud;
    systemctl "start $mariadb", timeout => 300;
    systemctl "is-active $mariadb";

    record_info("Version", script_output("$mariadb --version"));

    my $table = 'kv';
    assert_script_run("$mariadb -u root -e 'CREATE DATABASE IF NOT EXISTS $db;'");
    assert_script_run("$mariadb -u root -D $db -e 'CREATE TABLE IF NOT EXISTS $table (k VARCHAR(64) PRIMARY KEY, v VARCHAR(64));'");
    assert_script_run qq($mariadb -u root -D $db -e "INSERT INTO $table (k,v) VALUES ('check','pass');");
    assert_script_run qq($mariadb -u root -D $db -e "SHOW TABLES LIKE '$table'");
    record_info("Table", script_output(qq($mariadb -t -u root -D $db -e "SELECT k, v FROM $table;")));
    validate_script_output qq($mariadb -Nse "SELECT v FROM $table WHERE k='check';" $db), sub { m/^pass\s*$/ };

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

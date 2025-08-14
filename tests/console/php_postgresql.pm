# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: php? php?-pgsql postgresql*-contrib sudo unzip
# Summary: PHP? code that interacts locally with PostgreSQL
#   This tests creates a PostgreSQL database and inserts an element.
#   Then, PHP reads the elements and writes a new one in the database.
#   If all succeed, the test passes.
#
#   The test requires the Web and Scripting module on SLE
# - Setup apache2 to use php? modules
# - Install php?-pgsql postgresql*-contrib sudo
# - Start postgresql service
# - Populate postgresql with test db from data dir
# - Run a select command
# - Setup postgresql (password, access control)
# - Grab php test file from datadir
# - Run "curl --no-buffer http://localhost/test_postgresql_connector.php | grep 'can you read this?'"
# - Run select on database to check inclusion
# - Set PG_OLDEST, PG_LATEST and run a set of tests
#   - Create a new database
#   - Start/Stop/Status a database
#   - Upgrade a postgresql instance
#   - Cleanup database
# - Import and run dvdrental test
# - Cleanup postgresql database
# Maintainer: QE Core <qe-core@suse.com>


use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use apachetest qw(setup_apache2 setup_pgsqldb test_pgsql destroy_pgsqldb postgresql_cleanup);
use Utils::Systemd 'systemctl';
use Utils::Architectures 'is_aarch64';
use version_utils qw(is_leap is_sle php_version);

sub run {
    my $self = shift;
    select_serial_terminal;

    # ensure apache2 + php? installed and running
    my ($php, $php_pkg, $php_ver) = php_version();
    setup_apache2(mode => uc($php));

    # install requirements, all postgresql versions to test db upgrade if there are multiple versions
    zypper_call 'in ' . $php . '-pgsql postgresql*-contrib sudo unzip';

    # start postgresql service
    systemctl 'start postgresql';

    # setup database
    setup_pgsqldb;

    # For aarch64, sometimes serial terminal will stuck which causes failure.
    # So use root-console for aarch64. See poo#178639
    select_console 'root-console' if (is_aarch64);

    if (is_sle('=16.0')) {
        assert_script_run("setsebool -P httpd_can_network_connect_db 1");
    }

    # test itself
    test_pgsql;

    select_serial_terminal if (is_aarch64);
    # destroy database
    destroy_pgsqldb;

    # poo#62000
    postgresql_cleanup;
}

1;

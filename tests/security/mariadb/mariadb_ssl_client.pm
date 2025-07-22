# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run mariadb connect to server with '--ssl' parameter test case
# Maintainer: QE Security <none@suse.de>
# Tags: poo#109154, tc#1767518

use base 'consoletest';
use testapi;
use utils;
use Utils::Architectures;
use lockapi;
use network_utils 'iface';

sub run {
    my ($self) = @_;
    my $password = 'my_password';
    my $server_ip = get_var('SERVER_IP', '10.0.2.101');
    my $client_ip = get_var('CLIENT_IP', '10.0.2.102');

    select_console 'root-console';

    # Install runtime dependencies
    zypper_call("in iputils");

    # We don't run setup_multimachine in s390x, but we need to know the server and client's
    # ip address, so we add a known ip to NETDEV.
    my $netdev = iface;
    assert_script_run("ip addr add $client_ip/24 dev $netdev") if (is_s390x);

    zypper_call('in mariadb');
    mutex_wait('MARIADB_SERVER_READY');

    # Run MySQL tests
    perform_mariadb_test($server_ip, $password);

    # Delete the ip that we added if arch is s390x
    assert_script_run("ip addr del $client_ip/24 dev $netdev") if (is_s390x);
}

sub perform_mariadb_test {
    my ($server_ip, $password) = @_;

    # Test server connection
    assert_script_run("ping -c 3 $server_ip");
    validate_script_output("mysql --ssl -h $server_ip -u root -p$password -e \"show databases;\";", sub { m/Database/ });

    # Validate SSL connection
    validate_script_output("mysql --ssl -h $server_ip -u root -p$password -e \"SHOW STATUS LIKE 'Ssl_cipher';\";", sub { not m/DISABLED/ });

    # Create new database
    assert_script_run("mysql --ssl -h $server_ip -u root -p$password -e \"CREATE DATABASE test_db;\"");

    # Create new user
    assert_script_run("mysql --ssl -h $server_ip -u root -p$password -e \"CREATE USER 'test_user' IDENTIFIED BY 'test_password';\"");

    # Grant privileges to new user
    assert_script_run("mysql --ssl -h $server_ip -u root -p$password -e \"GRANT ALL PRIVILEGES ON test_db.* TO 'test_user';\"");

    # Validate user permissions
    assert_script_run("mysql --ssl -h $server_ip -u test_user -ptest_password -e \"USE test_db;\"");

    # Test data manipulation as the new user
    validate_script_output("mysql --ssl -h $server_ip -u test_user -ptest_password -e \"
        CREATE TABLE test_db.test_table (id INT, value VARCHAR(255));
        INSERT INTO test_db.test_table (id, value) VALUES (1, 'test_value');
        SELECT * FROM test_db.test_table;
        \";", sub { m/1\s+test_value/ }
    );
}

1;

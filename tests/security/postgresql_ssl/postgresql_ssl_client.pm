# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The client side of postgresql ssl connection test.
# Maintainer: Starry Wang <starry.wang@suse.com> Ben Chou <bchou@suse.com>
# Tags: poo#110233, tc#1769967

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;
use lockapi;

sub run {
    my ($self) = @_;
    my $server_ip = get_var('SERVER_IP', '10.0.2.101');
    my $client_ip = get_var('CLIENT_IP', '10.0.2.102');

    select_console 'root-console';

    # We don't run setup_multimachine in s390x, but we need to know the server and client's
    # ip address, so we add a known ip to NETDEV
    my $netdev = get_var('NETDEV', 'eth0');
    assert_script_run("ip addr add $server_ip/24 dev $netdev") if (is_s390x);
    systemctl("stop firewalld");

    zypper_call('in postgresql');
    mutex_wait('POSTGRESQL_SSL_SERVER_READY');

    # Try to connect postgresql server
    assert_script_run("ping -c 3 $server_ip");
    validate_script_output("psql -h $server_ip -U postgres -c \"select now();\";", sub { m/(1 row)/ });
}

1;

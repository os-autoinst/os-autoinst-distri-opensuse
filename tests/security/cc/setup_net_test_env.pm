# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Run 'netfilter' test case of 'audit-test' test suite
# Maintainer: Liu Xiaojing <xiaojing.liu@suse.com>
# Tags: poo#96540

use base 'consoletest';
use strict;
use warnings;
use testapi;
use autotest;
use utils;
use lockapi;
use mmapi 'wait_for_children';
use audit_test qw(compare_run_log prepare_for_test upload_audit_test_logs);
use scheduler 'get_test_suite_data';

sub run {
    my ($self) = shift;

    select_console 'root-console';

    zypper_call('in bridge-utils');

    # Need to do 'make netconfig' to generate 'lblnet_tst_server'
    prepare_for_test(make => 1, timeout => 900, make_netconfig => 1);

    # Configure the network
    my $data = get_test_suite_data();

    my $role = get_required_var('ROLE');
    foreach my $key (keys %{$data->{$role}}) {
        my $n       = $data->{$role}->{$key};
        my $netcard = $n->{netcard};
        my $dev     = $netcard;
        assert_script_run("ip link add link eth0 address $n->{mac_addr} $netcard type macvlan");

        # Network Bridge setting for Target of Evaluation(TOE)
        if ($role eq 'client' && $key eq 'second_interface') {
            assert_script_run('brctl addbr toebr');
            assert_script_run("brctl addif toebr $netcard");
            assert_script_run('brctl setageing toebr 3600');
            $dev = 'toebr';
        }

        assert_script_run("ip addr add $n->{ipv4} dev $dev");
        assert_script_run("ip addr add $n->{ipv6} dev $dev");
        assert_script_run("ip link set $netcard up");
        assert_script_run('ip link set toebr up') if ($role eq 'client' && $key eq 'second_interface');
        assert_script_run("ip -6 route add $n->{route} dev $dev");
    }

    # start lblnet_tst_server
    my $cmd        = "$audit_test::test_dir/audit-test/utils/network-server/lblnet_tst_server";
    my $lblnet_pid = background_script_run($cmd);

    if ($role eq 'server') {
        mutex_create('NETFILTER_SERVER_READY');
        wait_for_children;
    } else {
        mutex_wait('NETFILTER_SERVER_READY');

        # Export the variables
        my $client_first  = $data->{client}->{first_interface};
        my $client_second = $data->{client}->{second_interface};
        my $server_first  = $data->{server}->{first_interface};
        my $server_second = $data->{server}->{second_interface};

        # Deal with ipv4 address: change 192.168.0.1/24 to 192.168.0.1
        $client_first->{ipv4}  =~ s/\/.*//g;
        $client_second->{ipv4} =~ s/\/.*//g;
        $server_first->{ipv4}  =~ s/\/.*//g;
        $server_second->{ipv4} =~ s/\/.*//g;

        assert_script_run("export PASSWD=$testapi::password LOCAL_DEV=$client_first->{netcard}\@eth0 LOCAL_SEC_DEV=$client_second->{netcard}\@eth0 LOCAL_SEC_MAC=$client_second->{mac_addr} LOCAL_IPV4=$client_first->{ipv4} LOCAL_IPV6=$client_first->{ipv6} LOCAL_SEC_IPV4=$client_second->{ipv4} LOCAL_SEC_IPV6=$client_second->{ipv6} LBLNET_SVR_IPV4=$server_first->{ipv4} LBLNET_SVR_IPV6=$server_first->{ipv6} SECNET_SVR_IPV4=$server_second->{ipv4} SECNET_SVR_IPV6=$server_second->{ipv6} SECNET_SVR_MAC=$server_second->{mac_addr} BRIDGE_FILTER=toebr");

        my $run_netfilter_args = OpenQA::Test::RunArgs->new();
        $run_netfilter_args->{case_name} = 'netfilter';
        autotest::loadtest('tests/security/cc/run_net_case.pm', name => 'netfilter', run_args => $run_netfilter_args);
        my $run_netfilebt_args = OpenQA::Test::RunArgs->new();
        $run_netfilebt_args->{case_name} = 'netfilebt';
        autotest::loadtest('tests/security/cc/run_net_case.pm', name => 'netfilebt', run_args => $run_netfilebt_args);
    }
}

1;

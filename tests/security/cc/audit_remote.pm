# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run CC 'audit-remote' test case
# Maintainer: QE Security <none@suse.de>
# Tags: poo#96735

use base 'consoletest';
use testapi;
use utils;
use Utils::Architectures;
use lockapi;
use mmapi 'wait_for_children';
use audit_test qw(upload_audit_test_logs compare_run_log prepare_for_test);
use serial_terminal qw(select_serial_terminal);
use Utils::Architectures qw(is_s390x);

sub run {
    my ($self) = @_;
    is_s390x ? select_console 'root-console' : select_serial_terminal;
    zypper_call('in audit-audispd-plugins libcap-progs');

    my $server_ip = get_var('SERVER_IP', '10.0.2.101');
    my $client_ip = get_var('CLIENT_IP', '10.0.2.102');
    my $test_node = get_required_var('HOSTNAME');

    # We don't run setup_multimachine in s390x, but we need to know the server and client's
    # ip address, so we add a known ip to NETDEV.
    my $netdev = 'eth0';
    assert_script_run("ip addr add $server_ip/24 dev $netdev") if (is_s390x && $test_node eq 'server');
    assert_script_run("ip addr add $client_ip/24 dev $netdev") if (is_s390x && $test_node eq 'client');

    prepare_for_test(make => 1, timeout => 900, make_netconfig => 1);

    # Export password of root
    assert_script_run("export PASSWD=$testapi::password");

    # Export SYSTEMD_PAGER to let the journalctl exits automatically
    assert_script_run('export SYSTEMD_PAGER=""');

    if ($test_node eq 'server') {
        my $pid = background_script_run("$audit_test::test_dir/audit-test/utils/network-server/lblnet_tst_server");

        mutex_create('AUDIT_REMOTE_SERVER_READY');
        wait_for_children;

        # Delete the ip that we added if arch is s390x
        assert_script_run("ip addr del $server_ip/24 dev $netdev") if (is_s390x);
    }
    else {
        assert_script_run("export LOCAL_IPV4=$client_ip");
        assert_script_run("export LBLNET_SVR_IPV4=$server_ip");

        mutex_wait('AUDIT_REMOTE_SERVER_READY');

        # Run test cases individually
        my $test_name = 'audit-remote';
        assert_script_run("cd $test_name");
        # count the test cases
        my $ncases = script_output "grep -c '^+' run.conf";
        # If there are N cases, we need to iterate from 0 to N-1
        # unfortunately we can't parallellize because each sub-test wants to reset audit and rotate logs
        # result comparison will be done against the baseline when all the tests have run
        for (my $case = 0; $case < $ncases; $case++) {
            record_info "Running $test_name #$case ...";
            script_run("./run.bash $case", timeout => 600);
        }
        upload_audit_test_logs($test_name);
        # The 4th and 5th may fail because the audit log is generated slowly in server, we need to rerun it again
        assert_script_run('./run.bash 0', timeout => 600) if (script_run('grep -E "[0].*FAIL" rollup.log') == 0);
        assert_script_run('./run.bash 4', timeout => 600) if (script_run('grep -E "[4].*FAIL" rollup.log') == 0);
        assert_script_run('./run.bash 5', timeout => 600) if (script_run('grep -E "[5].*FAIL" rollup.log') == 0);

        my $result = compare_run_log($test_name);
        $self->result($result);

        # Delete the ip that we added if arch is s390x
        assert_script_run("ip addr del $client_ip/24 dev $netdev") if (is_s390x);
    }
}

1;

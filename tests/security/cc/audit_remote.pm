# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run CC 'audit-remote' test case
# Maintainer: QE Security <none@suse.de>
# Tags: poo#96735

use Mojo::Base 'consoletest';
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

    prepare_for_test(make => 1, timeout => 1200, make_netconfig => 1);

    # Export password of root
    assert_script_run("export PASSWD=$testapi::password");

    # Export SYSTEMD_PAGER to let the journalctl exits automatically
    assert_script_run('export SYSTEMD_PAGER=""');

    if ($test_node eq 'server') {
        # Redirect the test server's output to a log file.
        my $server_log = '/tmp/tst_server.log';
        my $pid = background_script_run(
            "$audit_test::test_dir/audit-test/utils/network-server/lblnet_tst_server > $server_log 2>&1");

        mutex_create('AUDIT_REMOTE_SERVER_READY');
        wait_for_children;

        # Shut the test server down so the serial console is responsive again
        script_run("kill $pid; sleep 1; kill -9 $pid 2>/dev/null", timeout => 30);
        upload_logs($server_log) if (script_run("test -s $server_log") == 0);

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
            script_run("./run.bash $case", timeout => 1200);
        }
        upload_audit_test_logs($test_name);

        # Tests 4 and 5 may fail when run after test 3 because the audit log
        # is generated slowly in server. Accept failures as softfail poo#197378
        my %expected_softfail_ids = (4 => 1, 5 => 1);

        # Collect which of the expected softfails actually failed,
        # so we can attach a single softfail.
        my $fail_output = script_output('grep -E "FAIL|ERROR" rollup.log', proceed_on_failure => 1);
        my @soft_failed;
        foreach my $line (split(/\n/, $fail_output)) {
            # Test names can contain spaces, so match greedily up to the trailing result word.
            if ($line =~ /\[(\d+)\]\s+(.*)\s+(FAIL|ERROR)\s*$/) {
                my ($id, $name, $res) = ($1, $2, $3);
                push @soft_failed, "[$id] $name $res" if $expected_softfail_ids{$id};
            }
        }
        record_soft_failure("poo#197378 - expected failure(s): "
              . join(', ', @soft_failed)
              . " (server side error)") if @soft_failed;

        my $result = compare_run_log($test_name, softfail_ids => \%expected_softfail_ids);
        $self->result($result);

        # Delete the ip that we added if arch is s390x
        assert_script_run("ip addr del $client_ip/24 dev $netdev") if (is_s390x);
    }
}

1;

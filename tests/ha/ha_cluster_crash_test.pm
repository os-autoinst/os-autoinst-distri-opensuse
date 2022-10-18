# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test HA cluster with cluster-preflight-check
# Test uses 'crm cluster crash_test' command to simulate multiple testcase scenarios:
# Force kill pacemakerd:
#   The pacemakerd process gets restarted by systemd. All RAs must stay intact.
# Force kill corosync
#   Node gets fenced since other node corosync just ran out of timeout and treat it as a node lost and forms a new membership.
# Force kill sbd
#   Node experiences the watchdog fencing.
# Split brain scenario
#   Split brain scenario by using iptable rules. Fencing is expected.
# More detailed explanation can be find in respective result files.
#
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use hacluster qw(check_cluster_state
  get_cluster_name
  get_node_index
  get_node_number
  ha_export_logs
  calculate_sbd_start_delay
  wait_until_resources_started
);
use utils qw(zypper_call);
use Mojo::JSON qw(encode_json);

our $dir_log = '/var/lib/crmsh/crash_test/';

sub upload_crash_test_logs {
    my @report_files = split(/\n/, script_output("ls $dir_log 2>/dev/null", proceed_on_failure => 1));
    upload_logs("$dir_log/$_", failok => 1) foreach (@report_files);
    upload_logs('/var/log/crmsh/crash_test.log', failok => 1);
}

sub run {
    my ($self) = @_;
    my $cluster_name = get_cluster_name;
    my $node_was_fenced = 0;

    # Ensure that the cluster state is correct before executing the checks
    select_serial_terminal;
    check_cluster_state;

    # We have to wait for previous nodes to finish the tests, as they can't be done in parallel without any damages!
    barrier_wait("PREFLIGHT_CHECK_INIT_${cluster_name}_NODE$_") foreach (1 .. (get_node_index) - 1);

    # List of things to check
    my @checks = qw(kill-sbd kill-corosync kill-pacemakerd split-brain-iptables);
    my $preflight_start_time = time;
    # Start delay after fencing to prevent node joining cluster too quickly
    my $start_delay_after_fencing = calculate_sbd_start_delay();

    # Loop on each check
    foreach my $check (@checks) {
        # reset fencing status form previous loop
        $node_was_fenced = 0;

        # Execute the command
        my $cmd = "crm cluster crash_test --$check --force";
        record_info($check, "Executing $cmd");
        my $cmd_fails = script_run($cmd, die_on_timeout => 0);

        # Killing pacemaker should result in service restart
        # All remaining commands lead to a reboot of the node
        my $loop_count = bmwqemu::scale_timeout(15);    # Wait 1 minute (15*4) maximum, can be scaled with SCALE_TIMEOUT
        while (1) {
            last if ($loop_count-- <= 0);
            if (check_screen('grub2', 0, no_wait => 1)) {
                # Wait for boot and reconnect to root console
                $self->wait_boot;
                select_serial_terminal;
                # Wait for fencing delay and resources to start
                sleep $start_delay_after_fencing;
                wait_until_resources_started();
                $node_was_fenced = 1;
                last;
            }
            sleep 4;
        }

        if ($check eq "kill-pacemakerd") {
            if ($node_was_fenced) {
                record_info('ERROR', "Failure while executing '$cmd'. Killing pacemaker should not trigger fencing", result => 'fail');
            }
            else {
                record_info('INFO', "Executing '$cmd' did not trigger fencing (expected behavior).");
            }
            next;
        }

        # remaining checks should trigger fencing
        if ($node_was_fenced) {
            record_info('WARNING', "The node was fenced while executing '$cmd'");
        }
        else {
            record_info('ERROR', "Failure while executing '$cmd'", result => 'fail') unless (defined $cmd_fails and $cmd_fails == 0);
        }
    }

    my $preflight_end_time = time;
    upload_crash_test_logs;

    # Parse the logs to get a better overview in openQA
    my $results_file = '/tmp/preflight_cluster.json';
    my %results = (
        tests => [],
        info => {timestamp => time, distro => "", results_file => ""},
        summary => {num_tests => 0, passed => 0, duration => $preflight_end_time - $preflight_start_time}
    );

    my $output = script_output("for FILE in $dir_log/*.report; do awk -F':' '/Testcase:|ERROR:/ { print }' ORS=' ' \$FILE 2>/dev/null && echo; done");
    foreach my $line (split("\n", $output)) {
        my @tab = split(/\s+/, $line);
        my %aux = ();
        $results{summary}->{num_tests}++;
        $aux{name} = lc(join('_', $tab[1], $tab[2], $tab[3]));
        $aux{outcome} = ($line =~ /ERROR:/) ? 'failed' : 'passed';
        $aux{test_index} = 0;
        push @{$results{tests}}, \%aux;
        $results{summary}->{passed}++ if ($aux{outcome} eq 'passed');
    }

    my $json = encode_json \%results;
    assert_script_run "echo '$json' > $results_file";

    # Upload IPA log
    parse_extra_log(IPA => $results_file);

    # Sync *next* nodes
    barrier_wait("PREFLIGHT_CHECK_INIT_${cluster_name}_NODE$_") foreach (get_node_index .. get_node_number);

    # Check the whole cluster state at the end
    check_cluster_state;
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

sub post_fail_hook {
    my ($self) = @_;

    # We need to be sure that *ALL* consoles are closed, are SUPER:post_fail_hook
    # does not support virtio/serial console yet
    reset_consoles;
    select_console('root-console');

    # Upload the logs
    $self->upload_crash_test_logs;
    ha_export_logs;

    # Execute the common part
    $self->post_fail_hook;
}

1;

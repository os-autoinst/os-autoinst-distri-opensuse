# SUSE's openQA tests
#
# Copyright (c) 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test HA cluster with cluster-preflight-check
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster qw(check_cluster_state get_cluster_name get_node_index get_node_number ha_export_logs);
use utils qw(zypper_call);
use Mojo::JSON qw(encode_json);

our $dir_log = '/var/lib/ha-cluster-preflight-check/';

sub upload_preflight_check_logs {
    my @report_files = split(/\n/, script_output("ls $dir_log 2>/dev/null", proceed_on_failure => 1));
    upload_logs("$dir_log/$_",                             failok => 1) foreach (@report_files);
    upload_logs('/var/log/ha-cluster-preflight-check.log', failok => 1);
}

sub run {
    my ($self) = @_;
    my $cluster_name = get_cluster_name;

    # Install needed package
    $self->select_serial_terminal;
    zypper_call 'in python3-cluster-preflight-check';

    # Ensure that the cluster state is correct before executing the checks
    check_cluster_state;

    # We have to wait for previous nodes to finish the tests, as they can't be done in parallel without any damages!
    barrier_wait("PREFLIGHT_CHECK_INIT_${cluster_name}_NODE$_") foreach (1 .. (get_node_index) - 1);

    # List of things to check
    my @checks    = qw(env-check cluster-check kill-sbd kill-corosync kill-pacemaker split-brain-iptables);
    my @can_fence = qw(kill-sbd kill-corosync kill-pacemaker split-brain-iptables);

    # Loop on each check
    my $preflight_start_time = time;
    foreach my $check (@checks) {
        # Is the check can trigger a fencing?
        my $trigger_fencing = grep { $_ eq $check } @can_fence;

        # Execute the command
        my $cmd = "ha-cluster-preflight-check --yes --${check}";
        record_info("${check}", "Executing ${cmd}");
        my $cmd_fails = script_run "${cmd}";
        record_info('ERROR', "Failure while executing '$cmd'", result => 'fail') unless ((defined $cmd_fails and $cmd_fails == 0) or $trigger_fencing);
        save_screenshot;

        # Some commands may lead to a reboot of the node
        if ($trigger_fencing) {
            my $loop_count = bmwqemu::scale_timeout(15);    # Wait 1 minute (15*4) maximum, can be scaled with SCALE_TIMEOUT
            while (1) {
                last if ($loop_count-- <= 0);
                if (check_screen('bootloader-grub2', 0, no_wait => 1)) {
                    # Wait for boot and reconnect to root console
                    $self->wait_boot;
                    $self->select_serial_terminal;
                    last;
                }
                sleep 4;
            }
        }
    }
    my $preflight_end_time = time;
    upload_preflight_check_logs;

    # Parse the logs to get a better overview in openQA
    my $results_file = '/tmp/preflight_cluster.json';
    my %results      = (
        tests   => [],
        info    => {timestamp => time, distro => "", results_file => ""},
        summary => {num_tests => 0,    passed => 0,  duration     => $preflight_end_time - $preflight_start_time}
    );

    my $output = script_output("for FILE in $dir_log/*.report; do awk -F':' '/Testcase:|ERROR:/ { print }' ORS=' ' \$FILE 2>/dev/null && echo; done");
    foreach my $line (split("\n", $output)) {
        my @tab = split(/\s+/, $line);
        my %aux = ();
        $results{summary}->{num_tests}++;
        $aux{name}       = lc(join('_', $tab[1], $tab[2], $tab[3]));
        $aux{outcome}    = ($line =~ /ERROR:/) ? 'failed' : 'passed';
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
    $self->upload_preflight_check_logs;
    ha_export_logs;

    # Execute the common part
    $self->post_fail_hook;
}

1;

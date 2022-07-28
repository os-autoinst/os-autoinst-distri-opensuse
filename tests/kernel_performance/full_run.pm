# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
#
# Summary: run performance cases
# Maintainer: Joyce Na <jna@suse.de>

package full_run;
use ipmi_backend_utils;
use strict;
use power_action_utils 'power_action';
use warnings;
use testapi;
use base 'y2_installbase';
use File::Basename;
use LWP::Simple;

sub full_run {
    my $time_out //= 6;
    my $list_path = "/root/qaset";
    my $remote_list = get_var("FULL_LIST");
    my $hostname = script_output "hostname";
    my $runlist = get_var("RUN_LIST");

    my $selperf_machine_status_getapi =
      "http://dashboard.qa2.suse.asia:8889/api/msg_queue/v1/get/qa-apac2.qa-perf.status.automation.machines.progress.";
    my $selperf_machine_status_popapi =
      "http://dashboard.qa2.suse.asia:8889/api/msg_queue/v1/pop/qa-apac2.qa-perf.status.automation.machines.progress.";

    #setup run list
    assert_script_run("wget -N -P $list_path $remote_list 2>&1");
    assert_script_run("cp $list_path/$runlist $list_path/list");

    if (get_var('FULLRUN_MONITOR')) {
        # clear host status first
        get($selperf_machine_status_popapi . $hostname . "/");
        my $hoststatus = get($selperf_machine_status_getapi . $hostname . "/");
        record_info($hostname, $hoststatus);
    }

    assert_script_run("/usr/share/qa/qaset/qaset reset");
    assert_script_run("/usr/share/qa/qaset/run/performance-run.upload_Beijing");
    while (1) {
        if ((script_run("cat /var/log/qaset/control/NEXT_RUN | grep '_'") == 0) ||
            (script_run("ps ax | grep [r]untest") == 0)) {
            last;
        }
        if ($time_out == 0) {
            die "Full run failed,please rerun.";
        }
        sleep 30;
        --$time_out;
    }
    if (get_var('FULLRUN_MONITOR')) {
        while () {
            my $hoststatus = get($selperf_machine_status_getapi . $hostname . "/");
            record_info($hostname, $hoststatus);
            if ($hoststatus =~ /Progress: DONE/) {
                last;
            }
            else {
                sleep 600;
            }
        }
    }
}

sub run {
    full_run;
}

sub post_fail_hook {
    my ($self) = @_;
    my $screenlog = script_output("ls -rt /var/log/qaset/calls | tail -n 1");
    upload_logs "/var/log/qaset/calls/$screenlog";
}

sub test_flags {
    return {fatal => 1};
}

1;

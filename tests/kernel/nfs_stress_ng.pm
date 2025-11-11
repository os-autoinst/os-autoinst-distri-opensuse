# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run stress-ng on NFS
#    Should run after nfs_client/server.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use serial_terminal;
use lockapi;
use utils;
use registration;
use version_utils 'is_sle';

sub parse_stress_ng_log {
    my ($file) = @_;
    my $out = script_output("cat $file 2>/dev/null || echo ''");

    my %results = (
        failed => 0,
        passed => 0,
        skipped => 0,
        untrustworthy => 0,
    );

    if ($out =~ /failed:\s+(\d+)/) { $results{failed} = $1; }
    if ($out =~ /passed:\s+(\d+)/) { $results{passed} = $1; }
    if ($out =~ /skipped:\s+(\d+)/) { $results{skipped} = $1; }
    if ($out =~ /metrics[- ]untrustworthy:\s+(\d+)/) { $results{untrustworthy} = $1; }

    return \%results;
}

sub server {
    barrier_wait('NFS_STRESS_NG_START');
    barrier_wait('NFS_STRESS_NG_END');

    script_run('nfsstat -s');
}

sub client {
    my ($self) = @_;
    my $local_nfs4 = "/home/localNFS4";
    my $local_nfs4_async = "/home/localNFS4async";
    my $stressor_timeout = get_var('NFS_STRESS_NG_TIMEOUT') // 3;
    my @paths = ($local_nfs4, $local_nfs4_async);

    # in case this is SLE we need packagehub for stress-ng, let's enable it
    if (is_sle) {
        add_suseconnect_product(get_addon_fullname('phub'));
    }

    zypper_call("in stress-ng");

    select_user_serial_terminal;
    assert_script_run("stress-ng --class 'filesystem?'");

    barrier_wait('NFS_STRESS_NG_START');

    my $result = 0;
    foreach my $path (@paths) {
        assert_script_run('cd ' . $path);
        my ($dirname) = $path =~ m|([^/]+)$|;
        my $yaml = "/tmp/stress-ng_${dirname}.yaml";
        my $log = "/tmp/stress-ng_${dirname}.log";

        my $run_stress_ng = "stress-ng --verbose --sequential -1 --timeout $stressor_timeout " .
          "--class filesystem " .
          "--metrics-brief --yaml $yaml --log-file $log";

        my $ret = script_run($run_stress_ng, timeout => $stressor_timeout * 100);

        my $metrics = parse_stress_ng_log($log);
        record_info(
            "Summary [$dirname]",
            "passed=$metrics->{passed}, failed=$metrics->{failed}, skipped=$metrics->{skipped}, untrustworthy=$metrics->{untrustworthy}"
        );

        if ($metrics->{failed} > 0 || $metrics->{untrustworthy} > 0) {
            record_info('stress-ng', "Detected failed or untrustworthy metrics on path: $path", result => 'fail');
            $result = 1;
        }
        # TEMP
        upload_logs($yaml, failok => 1);
        upload_logs($log, failok => 1);
    }

    barrier_wait('NFS_STRESS_NG_END');

    if ($result != 0) {
        record_info('stress-ng', "Failures detected", result => 'fail');
        $self->result('fail');
    }

    select_serial_terminal;
    script_run('nfsstat');
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $role = get_required_var('ROLE');

    if ($role eq 'nfs_client') {
        $self->client;
    } else {
        $self->server;
    }
}

sub post_fail_hook {
    my ($self) = @_;
    upload_logs('/tmp/stress-ng*.yaml', failok => 1);
    upload_logs('/tmp/stress-ng*.log', failok => 1);
    $self->SUPER::post_fail_hook;
}

1;

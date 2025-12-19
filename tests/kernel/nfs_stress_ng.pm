# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run stress-ng on NFS
#    This module validates NFS client/server functionality by running
#    filesystem-class stress-ng tests against mounted NFS exports.
#    The module expects a multi-machine setup with roles 'nfs_client'
#    and 'nfs_server' and should be scheduled after after nfs_client,
#    nfs_server modules.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use serial_terminal;
use lockapi;
use utils;
use registration;
use version_utils 'is_sle';
use repo_tools 'add_qa_head_repo';

sub check_nfs_mounts {
    my @paths = @_;

    my $output = script_output("mount");

    my %mounts;
    foreach my $line (split /\n/, $output) {
        # extract mountpoint path and filesystem type
        $mounts{$1} = $2 if $line =~ /\son\s+(\/\S+)\s+type\s+(\S+)/;
    }

    # ensure each element of @paths is an active NFS mount on the client,
    # and is indeed of nfs type, otherwise fail
    foreach my $required (@paths) {
        unless (exists $mounts{$required} && $mounts{$required} =~ /^nfs\d?/) {
            record_info("Missing or wrong type",
                "Required NFS mount '$required' is " . ($mounts{$required} // "not mounted"),
                result => 'fail');
            return 0;
        }
    }

    return 1;
}

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
    # allow to override the default exports
    my $exports = get_var('NFS_STRESS_EXPORTS');
    my @paths = $exports ? split(/,/, $exports) : ($local_nfs4, $local_nfs4_async);

    if (!check_nfs_mounts(@paths)) {
        $self->result('fail');
        barrier_wait('NFS_STRESS_NG_START');
        barrier_wait('NFS_STRESS_NG_END');
        return;
    }

    # in case this is SLE we need packagehub for stress-ng, let's enable it
    if (is_sle) {
        my $modules = get_available_modules();
        # in early development of sle phub isn't usually available so we use stress-ng
        # from qa repo
        if ($modules->{PackageHub}) {
            add_suseconnect_product(get_addon_fullname('phub'));
        } else {
            record_info('Warning', 'stress-ng from QA repo');
            add_qa_head_repo(priority => 100);
        }
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

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

This module runs filesystem-class C<stress-ng> workloads against NFS
mounts in a multi-machine openQA setup. It is intended to validate both
basic NFS functionality and filesystem stability under load.

The module operates in two roles:

=over 4

=item * C<nfs_client> - verifies required NFS mounts, installs C<stress-ng>,
runs the workload on each export, parses the generated metrics, and records
the results.

=item * C<nfs_server> - synchronizes with the client through barriers and
prints NFS statistics (C<nfsstat -s>) after the workload completes.

Before executing any stress tests, the client ensures that all required
mount points - either the default NFS paths or those provided via
C<NFS_STRESS_EXPORTS> - are present and mounted as real NFS filesystems.

=back

Metrics are parsed from the C<stress-ng> C<--metrics-brief> output. Any
failing or untrustworthy metrics are treated as test failures.

=head1 Configuration

The following openQA variables control the behavior of this module:

=head2 ROLE

Required. Must be either C<nfs_client> or C<nfs_server>. Determines
which execution path is taken.

=head2 NFS_STRESS_EXPORTS

Optional. Comma-separated list of client-side mount points where
C<stress-ng> will be executed. Example:

  '/home/localNFS3,/home/localNFS4'

If not set, the defaults

=over 4

=item * C</home/localNFS4>
=item * C</home/localNFS4async>

=back

are used.

=head2 NFS_STRESS_NG_TIMEOUT

Optional. Timeout (in seconds) for the C<stress-ng> workload. Defaults to 3.

This value is passed directly to the C<--timeout> argument of C<stress-ng>.

=cut

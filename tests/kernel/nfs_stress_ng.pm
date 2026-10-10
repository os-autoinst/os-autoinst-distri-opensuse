# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run filesystem-class stress-ng workloads against mounted NFS exports.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal;
use lockapi;
use utils;
use registration;
use version_utils qw(is_sle is_transactional);
use repo_tools 'add_qa_head_repo';
use package_utils 'install_package';
use Kernel::multimachine_topology qw(has_topology get_local_node);

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
    my $local_nfs4 = get_var('NFS_LOCAL_NFS4', '/var/lib/nfs-tests/localNFS4');
    my $local_nfs4_async = get_var('NFS_LOCAL_NFS4_ASYNC', '/var/lib/nfs-tests/localNFS4async');
    my $stressor_timeout = get_var('NFS_STRESS_NG_TIMEOUT') // 3;
    my $instances = get_var('NFS_STRESS_NG_INSTANCES', -1);
    my $exclude = get_var('NFS_STRESS_NG_EXCLUDE');
    # allow to override the default exports
    my $exports = get_var('NFS_STRESS_EXPORTS');
    my @paths = $exports ? split(/,/, $exports) : ($local_nfs4, $local_nfs4_async);
    # with a topology, several clients share the exports, each runs in its own
    # directory; stress-ng runs as the user, so it creates the directory itself
    my $client_dir = has_topology() ? '/stress-ng-' . get_local_node()->{id} : '';

    if (!check_nfs_mounts(@paths)) {
        $self->result('fail');
        barrier_wait('NFS_STRESS_NG_START');
        barrier_wait('NFS_STRESS_NG_END');
        return;
    }

    # in case this is SLE we need packagehub for stress-ng, let's enable it
    if (is_sle) {
        if (is_phub_ready) {
            add_suseconnect_product(get_addon_fullname('phub'));
        } else {
            record_info('Warning', 'stress-ng from QA repo');
            add_qa_head_repo(priority => 100);    # needed when phub is not yet available
        }
    }

    install_package('stress-ng', trup_continue => 1, trup_apply => 1);

    select_user_serial_terminal;
    assert_script_run("stress-ng --class 'filesystem?'");

    barrier_wait('NFS_STRESS_NG_START');

    my $result = 0;
    foreach my $path (@paths) {
        assert_script_run("mkdir -p $path$client_dir && cd $path$client_dir");
        my ($dirname) = $path =~ m|([^/]+)$|;
        my $yaml = "/tmp/stress-ng_${dirname}.yaml";
        my $log = "/tmp/stress-ng_${dirname}.log";

        my $run_stress_ng = "stress-ng --verbose --sequential $instances --timeout $stressor_timeout " .
          "--class filesystem " .
          "--metrics-brief --yaml $yaml --log-file $log";

        if ($exclude) {
            $run_stress_ng .= " --exclude $exclude";
            record_info('Excluding stressor:', "$exclude");
        }

        my $ret = script_run($run_stress_ng, timeout => $stressor_timeout * 200);

        my $metrics = parse_stress_ng_log($log);
        record_info(
            "Summary [$dirname]",
            "passed=$metrics->{passed}, failed=$metrics->{failed}, skipped=$metrics->{skipped}, untrustworthy=$metrics->{untrustworthy}"
        );

        if ($metrics->{failed} > 0 || $metrics->{untrustworthy} > 0) {
            record_info('stress-ng', "Detected failed or untrustworthy metrics on path: $path", result => 'fail');
            $result = 1;
        }
        if ($metrics->{passed} == 0) {
            record_info('stress-ng', "No stressor passed on path: $path", result => 'fail');
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

    if ($role =~ /^nfs_client/) {
        $self->client;
    } else {
        $self->server;
    }
}

sub post_fail_hook {
    my ($self) = @_;
    # the user terminal can still be busy with the stress-ng output
    select_serial_terminal;
    my $logs = script_output('ls /tmp/stress-ng_*.yaml /tmp/stress-ng_*.log 2>/dev/null', proceed_on_failure => 1);
    upload_logs($_, failok => 1) for grep { m{^/tmp/stress-ng_} } split ' ', $logs;
    # the generic hook hangs on the NFS mounts if the server is gone
    script_run('umount -a -l -t nfs,nfs4');
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

Runs filesystem-class C<stress-ng> workloads against mounted NFS exports to
validate NFS client/server stability under load. This module is designed to
execute in lockstep with L<tests/kernel/nfs_server.pm> and
L<tests/kernel/nfs_client.pm>, synchronised at runtime via shared barriers.
It should be scheduled after both C<nfs_server> and C<nfs_client>.

On the B<NFS client> node the module verifies that all required NFS mount
points are present and of the correct filesystem type, installs C<stress-ng>,
runs the full C<filesystem> stressor class sequentially against each export,
parses the generated YAML metrics, and records any failing or untrustworthy
results as test failures.

On the B<NFS server> node the module synchronises with the client through
barriers and records NFS server statistics via C<nfsstat -s> after the
workload completes.

=head1 Configuration

=head2 ROLE

Required. Set to C<nfs_client> or C<nfs_server> to select the node's role
in the multi-machine scenario. Every role that starts with C<nfs_client>,
for example C<nfs_client1>, is a client, so that a topology can have
several clients.

=head2 NFS_LOCAL_NFS4

Client-side mountpoint for the NFSv4 synchronous export used as the default
stress-ng target. Defaults to C</var/lib/nfs-tests/localNFS4>.

=head2 NFS_LOCAL_NFS4_ASYNC

Client-side mountpoint for the NFSv4 asynchronous export used as the default
stress-ng target. Defaults to C</var/lib/nfs-tests/localNFS4async>.

=head2 NFS_STRESS_EXPORTS

Comma-separated list of client-side mount points where C<stress-ng> will be
executed, overriding the C<NFS_LOCAL_NFS4> and C<NFS_LOCAL_NFS4_ASYNC> defaults.

=head2 NFS_STRESS_NG_TIMEOUT

Timeout in seconds passed to the C<stress-ng --timeout> option for each
stressor. Defaults to C<3>.

=head2 NFS_STRESS_NG_INSTANCES

Number of instances of each stressor, passed to the C<stress-ng
--sequential> option. Defaults to C<-1>, one instance per online CPU. On
machines with many CPUs, a lower number keeps the run within the time
limit of C<NFS_STRESS_NG_TIMEOUT> times 200 seconds per export.

=head2 NFS_STRESS_NG_EXCLUDE

Comma-separated list of C<stress-ng> stressors to skip, passed directly to
C<--exclude>. Excluded stressors are not run even if they belong to the
C<filesystem> class.

=head1 Barriers

=head2 NFS_STRESS_NG_START

Synchronises both nodes before the stress workload begins; the server waits
here while the client verifies mounts and installs C<stress-ng>.

=head2 NFS_STRESS_NG_END

Both nodes meet here after the stress workload is complete.

=cut

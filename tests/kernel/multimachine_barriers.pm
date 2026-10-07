# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Create the barriers of a multimachine test in its parallel parent job.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use lockapi;
use mmapi qw(get_parents get_children);
use scheduler 'get_test_suite_data';
use Kernel::multimachine_topology 'get_job_nodes';

my $ready = 'mm_barriers_ready';

sub run {
    my $data = get_test_suite_data() // {};
    my $barriers = $data->{multimachine_barriers};
    die 'multimachine_barriers missing from test_data' unless ref $barriers eq 'ARRAY' && @$barriers;

    # openQA finds the barriers of a job only in the job itself and its
    # parallel parents, so the parent creates them for all jobs
    my $parents = get_parents() // die 'Cannot get the parallel parents of this job';
    if (@$parents) {
        die "This job has several parallel parents (@$parents), but mm_barriers needs one parent of all jobs"
          if @$parents > 1;
        mutex_wait($ready, $parents->[0]);
        record_info('Barriers', "Created by the parallel parent job $parents->[0]");
        return;
    }

    my $children = get_children() // die 'Cannot get the parallel children of this job';
    my $jobs = 1 + keys %$children;
    if ($data->{multimachine_topology}) {
        my $nodes = scalar @{get_job_nodes()};
        die "multimachine_topology has $nodes nodes that run a job, but the openQA cluster has $jobs jobs"
          unless $nodes == $jobs;
    }
    for my $name (@$barriers) {
        barrier_create($name, $jobs) or die "Cannot create barrier $name";
    }
    mutex_create($ready) or die "Cannot create mutex $ready";
    record_info('Barriers', "Created for $jobs jobs:\n" . join("\n", @$barriers));
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

Create the barriers of a multimachine test from C<test_data>. Schedule
this module first in every job of the setup, before the installation.

openQA finds the barriers of a job only in the job itself and its
parallel parents. So the job without parallel parents creates the
barriers, for all jobs of its openQA cluster: itself and its parallel
children. Then it creates the mutex C<mm_barriers_ready>. The other jobs
wait for this mutex, so that no job waits on a barrier that does not
exist yet.

One job must be the parallel parent of all other jobs (C<PARALLEL_WITH>);
a job with more than one parallel parent fails. If the schedule has a
C<multimachine_topology>, the parent also checks that the number of its
nodes that run a job matches the number of jobs (see C<get_job_nodes> in
C<Kernel::multimachine_topology>).

=head1 Configuration

The schedule provides the barrier names in C<test_data>:

  test_data:
    multimachine_barriers:
      - PEER_READY
      - TRAFFIC_DONE

=cut

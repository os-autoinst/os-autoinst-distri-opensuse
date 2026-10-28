# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check the cgroup layout and controllers before the cgroup test suites
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use Kernel::cgroup qw(
  get_cgroup_mounts
  get_cgroup_mode
  get_cgroup_v2_path
  get_cgroup_v2_controllers
  get_cgroup_v1_controllers
  has_cgroup_controller
);

sub run {
    select_serial_terminal;

    my $mounts = get_cgroup_mounts();
    record_info('cgroup mounts', join("\n", map { "$_->{type} $_->{mountpoint} " . join(',', @{$_->{options}}) } @$mounts) || 'none');

    my $mode = get_cgroup_mode($mounts);
    die 'No cgroup file system is mounted' unless defined $mode;
    record_info('cgroup mode', $mode);

    record_info('cgroup v2', 'Path: ' . (get_cgroup_v2_path($mounts) // 'not mounted') . "\nControllers: " . (join(' ', get_cgroup_v2_controllers($mounts)) || 'none'));
    record_info('cgroup v1', 'Controllers: ' . (join(' ', get_cgroup_v1_controllers($mounts)) || 'none'));

    my @missing = grep { !has_cgroup_controller($_, $mounts) } split(/,/, get_var('CGROUP_REQUIRED_CONTROLLERS', ''));
    die 'Missing cgroup controllers: ' . join(' ', @missing) if @missing;
}

1;

=head1 Description

Smoke test for the cgroup setup of the SUT. Run it before the cgroup test
suites (LTP, kselftests and blktests), to find a SUT that cannot run them.

The test does these steps:

=over

=item * Record the C<cgroup> and C<cgroup2> mounts, the cgroup mode
(C<unified>, C<hybrid> or C<legacy>), and the controllers in the cgroup v1
and cgroup v2 hierarchies. It uses the C<Kernel::cgroup> helpers.

=item * Fail if no cgroup file system is mounted.

=item * Fail if a controller in C<CGROUP_REQUIRED_CONTROLLERS> is not in a
cgroup v1 or cgroup v2 hierarchy.

=back

Refer to poo#209476.

=head1 Configuration

=head2 CGROUP_REQUIRED_CONTROLLERS

Comma separated list of the controllers that the next test suites need, for
example C<cpu,memory,io>. Use the cgroup v2 names (C<io>) for cgroup v2 and
the cgroup v1 names (C<blkio>) for cgroup v1. Default is empty: the test
only records the cgroup setup.

=cut

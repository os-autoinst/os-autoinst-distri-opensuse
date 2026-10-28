# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: cgroup helpers for kernel tests.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::cgroup;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT_OK = qw(
  get_cgroup_mounts
  get_cgroup_mode
  get_cgroup_v2_path
  get_cgroup_v2_controllers
  get_cgroup_v1_controllers
  has_cgroup_controller
);

=head1 SYNOPSIS

cgroup helpers for kernel tests.

The kernel has two cgroup versions:

=over

=item * cgroup v1: each controller (C<memory>, C<cpu>, C<blkio>, ...) has
its own hierarchy. Each hierarchy is a C<cgroup> mount, usually
C</sys/fs/cgroup/E<lt>controllerE<gt>>. The mount options show the
controllers of the hierarchy.

=item * cgroup v2: there is only one hierarchy for all controllers. It is a
C<cgroup2> mount, usually C</sys/fs/cgroup>. The file C<cgroup.controllers>
in the root of the mount shows the controllers of the hierarchy.

=back

A controller can be in only one hierarchy at a time. systemd selects the
layout at boot (C<systemd.unified_cgroup_hierarchy>), see
C<get_cgroup_mode>.

To read the mounts only one time, get them with C<get_cgroup_mounts()> and
give them to the other helpers:

 my $mounts = get_cgroup_mounts();
 my $mode = get_cgroup_mode($mounts);
 my @ctrls = get_cgroup_v2_controllers($mounts);

If no mounts are given, each helper reads them again.

=cut

# Names of the cgroup v1 controllers, to find them in the mount options.
my @V1_CONTROLLERS = qw(
  blkio cpu cpuacct cpuset devices freezer hugetlb memory misc
  net_cls net_prio perf_event pids rdma
);

sub _parse_cgroup_mounts {
    my ($text) = @_;
    my @mounts;

    for my $line (split /\n/, $text // '') {
        my ($dev, $mountpoint, $type, $options) = split ' ', $line;
        next unless defined $type && $type =~ /^cgroup2?$/;
        push @mounts, {
            type => $type,
            mountpoint => $mountpoint,
            options => [split /,/, $options // ''],
        };
    }
    return \@mounts;
}

=head2 get_cgroup_mounts

 my $mounts = get_cgroup_mounts();

Reads C</proc/self/mounts> on the SUT and returns an array reference of the
C<cgroup> and C<cgroup2> mounts. Each item is a hash reference with the
keys C<type> (C<cgroup> or C<cgroup2>), C<mountpoint> and C<options> (an
array reference of the mount options). Returns an empty array reference if
no cgroup file system is mounted.

=cut

sub get_cgroup_mounts {
    return _parse_cgroup_mounts(script_output('cat /proc/self/mounts'));
}

=head2 get_cgroup_mode

 my $mode = get_cgroup_mode([$mounts]);

Returns the cgroup layout, with the names that systemd uses:

=over

=item * C<unified>: only cgroup v2 is mounted.

=item * C<hybrid>: cgroup v1 and cgroup v2 are mounted. Usually, the
controllers are in cgroup v1 and systemd uses cgroup v2 only to track
processes (C</sys/fs/cgroup/unified>).

=item * C<legacy>: only cgroup v1 is mounted.

=back

Returns undef if no cgroup file system is mounted.

=cut

sub get_cgroup_mode {
    my ($mounts) = @_;
    $mounts //= get_cgroup_mounts();

    my $v1 = grep { $_->{type} eq 'cgroup' } @$mounts;
    my $v2 = grep { $_->{type} eq 'cgroup2' } @$mounts;

    return 'hybrid' if $v1 && $v2;
    return 'unified' if $v2;
    return 'legacy' if $v1;
    return undef;
}

=head2 get_cgroup_v2_path

 my $path = get_cgroup_v2_path([$mounts]);

Returns the mount point of cgroup v2, for example C</sys/fs/cgroup> or
C</sys/fs/cgroup/unified>. Returns undef if cgroup v2 is not mounted.

=cut

sub get_cgroup_v2_path {
    my ($mounts) = @_;
    $mounts //= get_cgroup_mounts();

    my ($v2) = grep { $_->{type} eq 'cgroup2' } @$mounts;
    return $v2 ? $v2->{mountpoint} : undef;
}

=head2 get_cgroup_v2_controllers

 my @ctrls = get_cgroup_v2_controllers([$mounts]);

Returns the list of controllers in the cgroup v2 hierarchy, from the file
C<cgroup.controllers> in the root of the cgroup v2 mount. Returns an empty
list if cgroup v2 is not mounted, or if all controllers are in cgroup v1
(for example in C<hybrid> mode).

In cgroup v2, the I/O controller has the name C<io>. In cgroup v1, it has
the name C<blkio>.

=cut

sub get_cgroup_v2_controllers {
    my ($mounts) = @_;

    my $path = get_cgroup_v2_path($mounts);
    return () unless defined $path;
    return split(' ', script_output("cat $path/cgroup.controllers"));
}

=head2 get_cgroup_v1_controllers

 my @ctrls = get_cgroup_v1_controllers([$mounts]);

Returns the sorted list of controllers in the cgroup v1 hierarchies, from
the options of the C<cgroup> mounts. Returns an empty list if cgroup v1 is
not mounted.

=cut

sub get_cgroup_v1_controllers {
    my ($mounts) = @_;
    $mounts //= get_cgroup_mounts();

    my %known = map { $_ => 1 } @V1_CONTROLLERS;
    my %found;
    for my $mount (grep { $_->{type} eq 'cgroup' } @$mounts) {
        $found{$_} = 1 for grep { $known{$_} } @{$mount->{options}};
    }
    return sort keys %found;
}

=head2 has_cgroup_controller

 has_cgroup_controller($name, [$mounts]);

Returns true if the controller C<$name> is in a cgroup v1 or a cgroup v2
hierarchy. Use the name of the cgroup version that the test uses, for
example C<io> for cgroup v2 and C<blkio> for cgroup v1.

=cut

sub has_cgroup_controller {
    my ($name, $mounts) = @_;
    $mounts //= get_cgroup_mounts();

    return scalar grep { $_ eq $name } get_cgroup_v1_controllers($mounts), get_cgroup_v2_controllers($mounts);
}

1;

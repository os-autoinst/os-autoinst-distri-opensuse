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
  create_cgroup
  remove_cgroup
  enable_cgroup_controller
  get_io_max
  set_io_max
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

=head2 create_cgroup

 my $path = create_cgroup($name, [$mounts]);

Creates the cgroup C<$name> in the root of the cgroup v2 hierarchy and
returns its path, for example C</sys/fs/cgroup/$name>. Dies if cgroup v2 is
not mounted or if the cgroup exists.

=cut

sub create_cgroup {
    my ($name, $mounts) = @_;

    my $root = get_cgroup_v2_path($mounts);
    die 'cgroup v2 is not mounted' unless defined $root;
    assert_script_run("mkdir $root/$name");
    return "$root/$name";
}

=head2 remove_cgroup

 remove_cgroup($path, [timeout => $timeout]);

Removes the cgroup C<$path>. The cgroup must have no child cgroups. The
kernel removes a cgroup only after all its processes have exited, thus
C<rmdir> can fail with C<EBUSY> for a short time. The helper tries again
each second until C<timeout> (default 30 seconds), then it dies.

=cut

sub remove_cgroup {
    my ($path, %opts) = @_;
    my $timeout = $opts{timeout} // 30;

    assert_script_run("timeout $timeout sh -c 'until rmdir $path; do sleep 1; done'", timeout => $timeout + 10);
}

=head2 enable_cgroup_controller

 enable_cgroup_controller($path, $controller);

Enables the controller C<$controller> for the child cgroups of the cgroup
C<$path>: it writes C<+$controller> to C<$path/cgroup.subtree_control>.
The controller must be in C<$path/cgroup.controllers>. Dies if the
controller is not enabled after the write.

To use a controller in the cgroup that C<create_cgroup> creates, enable the
controller in the root of the cgroup v2 hierarchy.

=cut

sub enable_cgroup_controller {
    my ($path, $controller) = @_;

    assert_script_run("echo +$controller > $path/cgroup.subtree_control");
    assert_script_run("grep -qw $controller $path/cgroup.subtree_control");
}

sub _parse_io_max {
    my ($text, $majmin) = @_;

    for my $line (split /\n/, $text // '') {
        my ($dev, @limits) = split ' ', $line;
        next unless defined $dev && $dev eq $majmin;
        return {map { split /=/, $_, 2 } @limits};
    }
    return undef;
}

=head2 get_io_max

 my $limits = get_io_max($path, $majmin);

Reads C<$path/io.max> and returns a hash reference with the limits of the
block device C<$majmin> (for example C<7:0>). The keys are C<rbps>,
C<wbps>, C<riops> and C<wiops>, and a value is a number or C<max>. Returns
undef if the device has no limits.

=cut

sub get_io_max {
    my ($path, $majmin) = @_;

    return _parse_io_max(script_output("cat $path/io.max"), $majmin);
}

=head2 set_io_max

 set_io_max($path, $majmin, %limits);

Writes the limits C<%limits> of the block device C<$majmin> to
C<$path/io.max>, for example C<< set_io_max($cg, '7:0', wbps => 1048576) >>.
The keys are C<rbps>, C<wbps>, C<riops> and C<wiops>. Give the values in
bytes or I/O operations per second, or C<max> to remove a limit.

Reads C<io.max> again and returns true if all the limits have the given
values. Returns false if a limit has a different value.

=cut

sub set_io_max {
    my ($path, $majmin, %limits) = @_;

    my $values = join(' ', map { "$_=$limits{$_}" } sort keys %limits);
    assert_script_run("echo '$majmin $values' > $path/io.max");

    my $actual = get_io_max($path, $majmin) // {};
    return !grep { ($actual->{$_} // 'max') ne $limits{$_} } keys %limits;
}

1;

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
  create_cgroup
  remove_cgroup
  enable_cgroup_controller
  set_io_max
);
use Kernel::block_dev qw(create_loop_backing_file attach_loop_device);

# Write 4 MiB with a write limit of 1 MiB/s. Without the limit, the write
# takes much less than 1 second. A busy host can only make the write slower,
# thus only the minimum time is checked.
sub check_io_max {
    my ($mounts) = @_;
    my $backing = '/tmp/cgroup_smoke_io.img';

    create_loop_backing_file($backing, '64M');
    my $loop = attach_loop_device($backing);
    my ($majmin) = script_output("lsblk -dno MAJ:MIN $loop") =~ /(\d+:\d+)/;

    enable_cgroup_controller(get_cgroup_v2_path($mounts), 'io');
    my $cg = create_cgroup('openqa_cgroup_smoke', $mounts);
    die "Cannot set io.max for $loop ($majmin)" unless set_io_max($cg, $majmin, wbps => 1024 * 1024);

    my $out = script_output("sh -c 'echo \$\$ > $cg/cgroup.procs && exec env LC_ALL=C dd if=/dev/zero of=$loop bs=1M count=4 oflag=direct' 2>&1", timeout => 120);

    remove_cgroup($cg);
    assert_script_run("losetup -d $loop && rm -f $backing");

    my ($seconds) = $out =~ /copied, ([\d.]+) s/;
    die "Cannot parse the dd output:\n$out" unless defined $seconds;
    record_info('io.max', "4 MiB written to $loop with wbps=1 MiB/s in $seconds s");
    die "io.max does not limit the writes: 4 MiB written in $seconds s" if $seconds < 2;
}

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

    # blktests throtl needs the io controller in cgroup v2. If it is not
    # there, blktests shows all throtl tests as "not run".
    if (grep { $_ eq 'io' } get_cgroup_v2_controllers($mounts)) {
        check_io_max($mounts);
    } else {
        record_info('No io in v2', 'The io controller is not in cgroup v2: the io.max check is not done and blktests throtl tests are not run', result => 'softfail');
    }
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

=item * If the C<io> controller is in cgroup v2, check that C<io.max>
limits the writes: write 4 MiB with C<dd> and C<oflag=direct> to a loop
device, from a cgroup with C<wbps> set to 1 MiB/s. Fail if the write takes
less than 2 seconds. A busy host makes the write only slower, thus the
check does not fail because of the host load. If the C<io> controller is
not in cgroup v2, record a soft failure, because blktests does not run the
C<throtl> tests then.

=back

Refer to poo#209476.

=head1 Configuration

=head2 CGROUP_REQUIRED_CONTROLLERS

Comma separated list of the controllers that the next test suites need, for
example C<cpu,memory,io>. Use the cgroup v2 names (C<io>) for cgroup v2 and
the cgroup v1 names (C<blkio>) for cgroup v1. Default is empty: the test
only records the cgroup setup.

=cut

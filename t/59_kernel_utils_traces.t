use strict;
use warnings;
use Test::More;
use Test::MockModule;
use Test::Warnings;
use Mojo::File qw(tempdir);
use Kernel::utils qw(find_kernel_traces);

# Run the commands in a local shell like on the SUT, with dmesg reading a fixture
my $tmp = tempdir;
my $dmesg = $tmp->child('dmesg.txt')->spew(<<'END');
[    1.0] WARNING: CPU: 0 PID: 1 at drivers/foo.c:1 boot_warn
[    1.1] Call Trace:
[   10.0] run fstests generic/002 at 2026-11-11 10:00:00
[   10.1] XFS (loop0): Mounting V5 Filesystem
[   10.2] WARNING: CPU: 1 PID: 42 at fs/xfs/xfs_foo.c:10 xfs_foo
[   10.3] Call Trace:
[   10.4]  <TASK>
[   10.5] BUG: MAX_STACK_TRACE_ENTRIES too low
[   10.6] XFS (loop0): Internal error xfs_bar, BUG: at fs/xfs/xfs_bar.c:5
END
my $filter = $tmp->child('dmesg_filter')->spew("Internal error\n");
my $clean = $tmp->child('clean.dmesg')->spew("[ 1.0] XFS (loop0): Ending clean mount\n");

my @cmds;
sub run_local {
    my ($cmd, $opts) = @_;
    push @cmds, $cmd;
    my $script = $tmp->child('cmd.sh')->spew("dmesg() { cat $dmesg; }\n$cmd\n");
    return scalar qx(bash $opts $script);
}
my $mock = Test::MockModule->new('Kernel::utils');
$mock->redefine(script_output => sub { run_local($_[0], '-o pipefail -e') });
$mock->redefine(script_run => sub { run_local($_[0], ''); $? >> 8 });

subtest 'since marker, with global and file filters' => sub {
    my $traces = find_kernel_traces(
        since => 'run fstests generic/002 at',
        ignore => ['BUG: MAX_STACK_TRACE_ENTRIES too low'],
        ignore_file => "$filter");
    is_deeply $traces, ['[   10.3] Call Trace:'], 'only the trace after the marker, filtered lines removed';
};

subtest 'missing marker' => sub {
    @cmds = ();
    is find_kernel_traces(since => 'run fstests generic/999 at'), undef, 'undef if the marker is not found';
    is scalar @cmds, 1, 'no search without the marker';
};

subtest 'missing ignore_file is not an error' => sub {
    my $traces = find_kernel_traces(since => 'run fstests generic/002 at', ignore_file => "$tmp/none");
    is scalar @$traces, 3, 'Call Trace and both BUG lines found';
};

subtest 'file' => sub {
    is_deeply find_kernel_traces(file => "$clean"), [], 'empty list for a clean log';
    like $cmds[-1], qr/^cat \S+clean\.dmesg \|/, 'reads the file';
};

done_testing;

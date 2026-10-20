# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Generic kernel-related helpers shared across kernel test modules.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils qw(systemctl write_sut_file);
use Mojo::JSON 'decode_json';

our @EXPORT_OK = qw(
  is_debugfs_mounted
  get_mount_info
  enable_debugfs
  get_kernel_config
  get_verified_shallow_tar
  start_trace_events
  save_trace
  install_fio_debug_wrapper
);

my $TRACEFS = '/sys/kernel/tracing';

=head2 is_debugfs_mounted

 is_debugfs_mounted();

Checks whether debugfs is mounted at /sys/kernel/debug, same check as
blktests' C<_have_debugfs()>. Returns true/false.

=cut

sub is_debugfs_mounted {
    return script_run('findmnt -t debugfs /sys/kernel/debug') == 0;
}

=head2 get_mount_info

 my $mount = get_mount_info($path);

Returns a hash reference with C<target>, C<source>, C<fstype> and
C<options> of the file system that C<$path> is on, from C<findmnt -T>.
For example, C<target> C</var>, C<source> C</dev/sda2[/@/var]>, C<fstype>
C<btrfs>. Dies if C<$path> is on no mounted file system.

=cut

sub get_mount_info {
    my ($path) = @_;
    my $json = script_output("findmnt -J -T $path -o TARGET,SOURCE,FSTYPE,OPTIONS");
    my $mount = decode_json($json)->{filesystems}[0];
    die "No mounted file system for $path" unless $mount;
    return $mount;
}

=head2 enable_debugfs

 enable_debugfs();

Mounts debugfs at /sys/kernel/debug (e.g. on SLE 16.1+, where it is
disabled by default per PED-8812).

=cut

sub enable_debugfs {
    record_info('debugfs', 'debugfs not mounted, enabling sys-kernel-debug.mount');
    systemctl('enable --now sys-kernel-debug.mount');
}

=head2 get_kernel_config

 get_kernel_config();

Locates the running kernel's config file (C</boot/config-$(uname -r)>,
falling back to C</usr/lib/modules/$(uname -r)/config> and then
C</proc/config.gz>) and records its full contents via C<record_info()>,
prefixed with a comment naming the source file (as done in
C<LTP::utils::log_versions>).

=cut

sub get_kernel_config {
    my $config = script_output(
        'ls -U "/boot/config-$(uname -r)" "/usr/lib/modules/$(uname -r)/config" /proc/config.gz 2>/dev/null | head -n 1',
        proceed_on_failure => 1
    );

    unless ($config) {
        record_info('kernel config', 'No kernel config file found');
        return;
    }

    upload_logs($config, failok => 1);

    my $cmd = "echo '# $config'; echo; " . ($config =~ /\.gz$/ ? "zcat $config" : "cat $config");
    record_info('kernel config', script_output($cmd));
}

=head2 get_verified_shallow_tar

 get_verified_shallow_tar(tree => 'stable', branch => 'linux-6.12.y', commit => '...');

Downloads the kernel.org shallow-clone tarball for the given C<tree> and
C<branch>, verifies it via the signed checksums, and checks out C<commit>
into F<./linux>. C<commit> should always be supplied in CI; omitting it
checks out the current tip (the bundle is published nightly).

See L<https://people.kernel.org/monsieuricon/using-shallow-git-tarballs-for-ci>.

=cut

sub get_verified_shallow_tar {
    my (%args) = @_;
    my $tree = $args{tree} // 'torvalds';
    my $branch = $args{branch} // 'master';
    my $commit = $args{commit} // '';

    my $script = 'get-verified-shallow-tar';
    assert_script_run('curl -fO ' . autoinst_url("/data/kernel/$script"));
    assert_script_run("chmod +x $script");
    assert_script_run('export GNUPGHOME=""');
    my $cmd = "./$script $tree $branch";
    $cmd .= " $commit" if $commit;
    assert_script_run($cmd, 1800);
}

=head2 start_trace_events

 start_trace_events(\@events);
 start_trace_events(\@events, filters => {$event => $filter}, buffer_kb => $kb);

Enable kernel tracepoints in tracefs and start to trace. Each event is
C<system/event>, a shell glob selects several events, e.g. C<nfs4/pnfs_*>.
Events that the kernel does not provide are skipped.

The events go to the trace ring buffer, which keeps the newest events when it
is full. Thus the trace can run for a long time without filling the disk.
C<save_trace> saves it.

If the first event is enabled already, e.g. by an earlier call before each
subtest, only clear the trace. This keeps repeated calls short. After a
reboot the events are enabled again.

Arguments:
  \@events  - Events to enable
  filters   - Optional event filters, e.g. C<'dev == 7340033'>
  buffer_kb - Optional ring buffer size per CPU in KiB (default: 8192)

=cut

sub start_trace_events {
    my ($events, %args) = @_;
    my $filters = $args{filters} // {};
    my $buffer_kb = $args{buffer_kb} // 8192;

    return if script_run("grep -qsx 1 $TRACEFS/events/$events->[0]/enable && echo > $TRACEFS/trace") == 0;
    my @cmds = ('echo 0 > tracing_on', 'echo > trace', "echo $buffer_kb > buffer_size_kb");
    push @cmds, 'for e in ' . join(' ', map { "events/$_" } @$events) . '; do [ -f $e/enable ] && echo 1 > $e/enable; done';
    push @cmds, "echo '$filters->{$_}' > events/$_/filter" foreach sort keys %$filters;
    push @cmds, 'echo 1 > tracing_on';
    script_run("(cd $TRACEFS && " . join('; ', @cmds) . ')');
}

=head2 save_trace

 save_trace($file);

Save the trace started by C<start_trace_events> to C<$file>.

=cut

sub save_trace {
    my ($file) = @_;

    script_run("cat $TRACEFS/trace > $file");
}

=head2 install_fio_debug_wrapper

 install_fio_debug_wrapper($dir);

Install a wrapper as F</usr/local/bin/fio>, so that tests which call fio from
C<PATH> run it with C<--debug=file,mem> and C<strace> of the failed syscalls.
For each fio run the wrapper keeps the job file, the command line, the debug
output and the strace output in C<$dir>, named by the pid of the wrapper.

Only fio runs that write the results to a file with C<--output=> are changed,
else the debug output would change the output of the test. The debug output is
kept out of the C<--output> file too, tests often copy this file to their logs.

Without C<strace> 5.2 or newer (for C<-Z>) fio runs without strace.

=cut

sub install_fio_debug_wrapper {
    my ($dir) = @_;
    my $wrapper = '/usr/local/bin/fio';

    return if script_run("test -e $wrapper") == 0;
    my $fio = script_output('type -P fio', proceed_on_failure => 1);
    return unless $fio =~ m{^/};
    my $strace = script_run('strace -f -Z -o /dev/null true') == 0 ? 'strace -f -tt -Z -o "$dir/$$.strace"' : '';

    my $script = <<'END';
#!/bin/bash
# Installed by Kernel::utils::install_fio_debug_wrapper
dir=@DIR@
args=()
for arg in "$@"; do
    if [[ $arg == --output=* ]]; then
        out=${arg#--output=}
        arg="--output=$dir/$$.out"
    fi
    args+=("$arg")
done
[ -n "$out" ] && mkdir -p "$dir" || exec @FIO@ "$@"
for arg in "$@"; do
    [ -f "$arg" ] && cp "$arg" "$dir/$$.job"
done
echo "@FIO@ $*" > "$dir/$$.cmd"
# fio writes the debug output to stdout until it opens the output file
@STRACE@ @FIO@ --debug=file,mem "${args[@]}" > "$dir/$$.stdout"
ret=$?
grep -Ev '^(file|mem) +[0-9]+ ' "$dir/$$.out" > "$out"
exit $ret
END
    $script =~ s/\@DIR\@/$dir/g;
    $script =~ s/\@FIO\@/$fio/g;
    $script =~ s/\@STRACE\@/$strace/g;
    write_sut_file($wrapper, $script);
    assert_script_run("chmod a+x $wrapper");
}

1;

# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: bpftrace
# Summary: Compile and attach eBPF probes with bpftrace
# Maintainer: kernel-qa@suse.de

use Mojo::Base qw(opensusebasetest);
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    zypper_call('in bpftrace bpftrace-tools');

    assert_script_run('bpftrace --info');

    my $trace_points = script_output('bpftrace -l "*openat"');

    unless ($trace_points =~ /tracepoint:syscalls:sys_enter_openat/) {
        die 'Common tracepoint (tracepoint:syscalls:sys_enter_openat) was not found in probe list';
    }

    my $tools_dir = '/usr/share/bpftrace/tools';

    my @assert_tests = qw(
      bashreadline.bt
      bitesize.bt
      capable.bt
      cpuwalk.bt
      dcsnoop.bt
      execsnoop.bt
      gethostlatency.bt
      killsnoop.bt
      loads.bt
      naptime.bt
      oomkill.bt
      opensnoop.bt
      pidpersec.bt
      runqlat.bt
      runqlen.bt
      setuids.bt
      ssllatency.bt
      sslsnoop.bt
      statsnoop.bt
      swapin.bt
      syncsnoop.bt
      syscount.bt
      tcpaccept.bt
      tcpconnect.bt
      tcplife.bt
      tcpretrans.bt
      tcpsynbl.bt
      threadsnoop.bt
      undump.bt
      vfscount.bt
      writeback.bt);

    my @tests = qw(
      biolatency.bt
      biosnoop.bt
      biostacks.bt
      mdflush.bt
      xfsdist.bt);

    if (is_sle('<=15-SP5')) {
        push(@assert_tests, 'old/tcpdrop.bt');
        push(@tests, 'vfsstat.bt');

    } else {
        push(@assert_tests, 'tcpdrop.bt');
        push(@assert_tests, 'vfsstat.bt');
    }

    foreach my $t (@assert_tests) {
        assert_script_run("timeout --preserve-status -s SIGINT 5 bpftrace $tools_dir/$t");
    }

    foreach my $t (@tests) {
        script_run("timeout --preserve-status -s SIGINT 5 bpftrace $tools_dir/$t");
    }
}

1;

=head1 Discussion

First we check that we can list tracepoints and that a common
tracepoint is available.

Be warned that other hooks are not stable. Tracepoints are part of the
ABI, but may not be available on all configurations.

Next we try running some prepackaged scripts. We check that most of
them execute without a critical error. This is a smoke test.

Some scripts need particular kernel versions. The new tcpdrop.bt
requires kernel 5.17+.

Scripts that will not execute correctly on TW or SLE are run without
asserting the return value. These use kprobes which are not stable.

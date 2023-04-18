# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: bpftrace
# Summary: Compile and attach eBPF probes with bpftrace
# Maintainer: kernel-qa@suse.de

use Mojo::Base qw(opensusebasetest);
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';
use serial_terminal;
use Mojo::File 'path';

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
      pidpersec.bt
      runqlat.bt
      runqlen.bt
      setuids.bt
      ssllatency.bt
      sslsnoop.bt
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
      opensnoop.bt
      statsnoop.bt
      xfsdist.bt
      vfsstat.bt
      tcpdrop.bt
      old/tcpdrop.bt);

    foreach my $t (@assert_tests) {
        my $ret = script_run("timeout --preserve-status -s SIGINT 10 bpftrace $tools_dir/$t");

        if ($ret == 130) {
            record_info('timeout', "'bpftrace $t' did not handle SIGINT; system was probably too slow to attach probes");
        } elsif ($ret) {
            die "'bpftrace $t' failed";
        }
    }

    foreach my $t (@tests) {
        script_run("timeout --preserve-status -s SIGINT 10 bpftrace $tools_dir/$t");
    }

    my $case_dir = get_required_var('CASEDIR');
    my $open_bt = path("$case_dir/data/kernel/open.bt")->slurp();

    background_script_run("while sleep 5; do touch opentest; done");

    my $cmd_text = "bpftrace -";
    wait_serial(serial_term_prompt(), no_regex => 1);
    type_string($cmd_text);
    wait_serial($cmd_text, no_regex => 1);
    send_key('ret');
    type_string($open_bt, terminate_with => 'EOT');
    wait_serial(qr/Found it; PID == \d+!/);
}

1;

=head1 Discussion

First we check that we can list tracepoints and that a common
tracepoint is available.

Be warned that other hooks are not stable. Tracepoints are part of the
ABI, but may not be available on all configurations.

Next we try running some prepackaged scripts. We check that most of
them execute without a critical error. This is a smoke test.

Scripts that will not execute correctly on TW, SLE or some arch are
run without asserting the return value.

Some scripts need particular kernel versions. The new tcpdrop.bt
requires kernel 5.17+.

opensnoop.bt/statsnoop.bt does not work on Aarch64 because of:
https://github.com/iovisor/bpftrace/issues/1838

If bpftrace is terminated before attaching the probes then it doesn't
handle SIGINT and assert_script_run fails. Once the probes are
attached it handles SIGINT gracefully.

Finally we run open.bt which traces opening files. It exits when it
sees opentest being opened. We check the output to verify the script
ran correctly and found the event.

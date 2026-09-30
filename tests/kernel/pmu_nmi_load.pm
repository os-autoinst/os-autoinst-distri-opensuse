# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: perf stress-ng
# Summary: Check that perf sampling on a hardware PMU generates NMIs
# without kernel errors
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use version_utils 'is_sle';
use registration qw(is_phub_ready add_suseconnect_product get_addon_fullname);
use repo_tools 'add_qa_head_repo';
use Kernel::cpu qw(
  lscpu_info
  get_cpu_model
  get_cpu_count
  get_online_cpus
  get_offline_cpus
  get_present_cpus
  get_cpu_topology
  get_cpu_flags
  get_cpu_vulnerabilities
  has_hw_pmu
  nmi_count
);

sub record_cpu_info {
    my $info = lscpu_info();
    record_info('get_cpu_model', get_cpu_model($info) // 'undef');
    record_info('get_cpu_count', get_cpu_count($info));
    record_info('get_online_cpus', join(',', get_online_cpus()));
    record_info('get_offline_cpus', join(',', get_offline_cpus()) || 'none');
    record_info('get_present_cpus', join(',', get_present_cpus()));
    my $topology = get_cpu_topology($info);
    record_info('get_cpu_topology', join("\n", map { "$_: " . ($topology->{$_} // 'undef') } sort keys %$topology));
    record_info('get_cpu_flags', join(' ', get_cpu_flags($info)) || 'none');
    my $vulns = get_cpu_vulnerabilities();
    record_info('get_cpu_vulnerabilities', join("\n", map { "$_: $vulns->{$_}" } sort keys %$vulns) || 'none');
}

# Run a perf sampling command and check that the NMI count increased
sub run_perf_sampling {
    my ($name, $cmd, $duration) = @_;

    my $nmi_before = nmi_count();
    assert_script_run($cmd, timeout => $duration + 120);
    my $nmi_after = nmi_count();
    my $nmi_delta = $nmi_after - $nmi_before;
    record_info("NMI $name", "NMI count before: $nmi_before\nNMI count after: $nmi_after\nDelta: $nmi_delta");
    die "NMI count did not increase during perf sampling ($name)" unless $nmi_delta > 0;
}

sub install_perf_stress {
    install_package('perf');

    if (is_sle) {
        if (is_phub_ready) {
            add_suseconnect_product(get_addon_fullname('phub'));
        } else {
            record_info('Warning', 'stress-ng from QA repo');
            add_qa_head_repo(priority => 100);
        }
    }
    install_package('stress-ng', trup_continue => 1, trup_apply => 1);
}

sub run {
    my ($self) = @_;
    my $duration = get_var('PMU_NMI_LOAD_DURATION', 30);

    select_serial_terminal;
    install_perf_stress();

    record_cpu_info();

    record_info('PMU', script_output('ls /sys/bus/event_source/devices/'));

    # Without a hardware PMU, perf uses software events only and no NMI
    # is generated. The test result is then not relevant.
    unless (has_hw_pmu()) {
        record_info('SKIP', 'No hardware PMU available, perf cannot generate NMIs');
        $self->result('skip');
        return;
    }

    my @dmesg_before = split(/\n/, script_output('dmesg'));
    my $dmesg_lines = @dmesg_before;

    # Initial test: sample on the idle system. Idle CPUs produce few
    # cycles, so the NMI rate is low.
    run_perf_sampling('idle', "perf record -a -F 10000 -o /tmp/pmu_nmi_load.data sleep $duration", $duration);
    script_run('rm -f /tmp/pmu_nmi_load.data');

    # Test with load: keep all online CPUs busy with stress-ng, so that
    # each CPU gets a high NMI rate. The context switches make NMIs also
    # interrupt kernel entry and exit code. The samples are not needed, so
    # write them to a pipe and discard them.
    run_perf_sampling('load', "perf record -a -F 10000 -o - -- stress-ng --cpu 0 --switch 0 --timeout ${duration}s > /dev/null", $duration);

    # TODO: This dmesg check is an initial solution. Investigate how to do
    # this check with the openQA serial failure detection (known_bugs.pm)
    # and then remove it.
    my @dmesg = split(/\n/, script_output('dmesg'));
    my @errors = grep { /BUG:|Oops|WARNING:|general protection|unchecked MSR/ } @dmesg[$dmesg_lines .. $#dmesg];
    die "Kernel errors found during perf sampling:\n" . join("\n", @errors) if @errors;
}

sub test_flags {
    return {fatal => 0};
}

1;

=head1 Description

Check that the hardware Performance Monitoring Unit (PMU) generates
non-maskable interrupts (NMIs) during C<perf> sampling, and that the kernel
does not log errors while it handles them.

The test does these steps:

=over

=item * Install C<perf> and C<stress-ng>.

=item * Record the CPU information from the C<Kernel::cpu> helpers (model,
CPU lists, topology, flags and vulnerability status) and the available
C<perf> event sources.

=item * Check that the C<cycles> hardware event is supported. If it is not
supported (for example, in a virtual machine without a virtual PMU), the
test is skipped, because C<perf> generates no NMIs.

=item * Run C<perf record> on all CPUs at 10000 Hz on the idle system, and
check that the NMI count in C</proc/interrupts> increased.

=item * Run C<perf record> again while C<stress-ng> keeps all online CPUs
busy and does context switches, and check that the NMI count increased.

=item * Check that no C<BUG:>, C<Oops>, C<WARNING:>, C<general protection>
or C<unchecked MSR> message was added to the kernel log.

=back

Refer to poo#114460: on some Intel CPUs, NMIs caused kernel crashes after
the RETBLEED fixes, and the automated tests did not detect it. On a virtual
machine, set C<QEMUCPU=host> to make a virtual PMU available.

=head1 Configuration

=head2 PMU_NMI_LOAD_DURATION

Duration of each C<perf record> sampling (idle and with load) in seconds.
Default is 30.

=cut

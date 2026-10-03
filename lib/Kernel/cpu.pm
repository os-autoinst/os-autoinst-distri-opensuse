# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: CPU helpers for kernel tests.
# Maintainer: Kernel QE <kernel-qa@suse.de>

package Kernel::cpu;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use Kernel::irq qw(get_interrupts get_irq_total);

our @EXPORT_OK = qw(
  lscpu_info
  get_cpu_model
  get_cpu_count
  get_online_cpus
  get_offline_cpus
  get_present_cpus
  get_cpu_topology
  get_cpu_map
  get_cpu_flags
  has_cpu_flag
  get_cpu_vulnerabilities
  has_hw_pmu
  nmi_count
);

=head1 SYNOPSIS

CPU helpers for kernel tests.

To run C<lscpu> only one time, get the data with C<lscpu_info()> and give
it to the other helpers:

 my $info = lscpu_info();
 my $model = get_cpu_model($info);
 my $count = get_cpu_count($info);

If no data is given, each helper runs C<lscpu> again.

=cut

sub _parse_lscpu {
    my ($text) = @_;
    my %info;

    for my $line (split /\n/, $text // '') {
        next unless $line =~ /^\s*([^:]+?)\s*:\s*(.*?)\s*$/;
        $info{$1} //= $2;
    }
    return \%info;
}

=head2 lscpu_info

 my $info = lscpu_info();

Runs C<LC_ALL=C lscpu> on the SUT and returns a hash reference of field
name to value, for example C<< $info->{'Model name'} >>. The leading
indentation of new C<lscpu> versions is ignored. If a field occurs more
than one time, the first value is kept.

=cut

sub lscpu_info {
    return _parse_lscpu(script_output('LC_ALL=C lscpu'));
}

sub _expand_cpu_list {
    my ($list) = @_;
    my @cpus;

    for my $range (split /,/, $list // '') {
        $range =~ s/^\s+|\s+$//g;
        next if $range eq '';
        die "Invalid CPU list: '$list'" unless $range =~ /^(\d+)(?:-(\d+))?$/;
        push @cpus, $1 .. ($2 // $1);
    }
    return sort { $a <=> $b } @cpus;
}

=head2 get_cpu_model

 my $model = get_cpu_model([$info]);

Returns the CPU model name, from the C<lscpu> C<Model name> field. If it is
not available (for example on s390x), returns the C<Machine type>, then the
C<Model> field. Returns undef if none is available.

=cut

sub get_cpu_model {
    my ($info) = @_;
    $info //= lscpu_info();

    return $info->{'Model name'} // $info->{'Machine type'} // $info->{Model};
}

=head2 get_cpu_count

 my $count = get_cpu_count([$info]);

Returns the number of online CPUs, from the C<lscpu>
C<On-line CPU(s) list> field. Offline CPUs are not counted.

=cut

sub get_cpu_count {
    my ($info) = @_;
    $info //= lscpu_info();

    my $online = $info->{'On-line CPU(s) list'};
    die "lscpu has no 'On-line CPU(s) list' field" unless defined $online;
    my @cpus = _expand_cpu_list($online);
    return scalar(@cpus);
}

sub _read_cpu_list {
    my ($name) = @_;
    return _expand_cpu_list(script_output("cat /sys/devices/system/cpu/$name"));
}

=head2 get_online_cpus

 my @cpus = get_online_cpus();

Returns the list of online CPU numbers, from
C</sys/devices/system/cpu/online>.

=cut

sub get_online_cpus {
    return _read_cpu_list('online');
}

=head2 get_offline_cpus

 my @cpus = get_offline_cpus();

Returns the list of offline CPU numbers, from
C</sys/devices/system/cpu/offline>. These CPUs are present or possible,
but not online. Returns an empty list if all CPUs are online.

=cut

sub get_offline_cpus {
    return _read_cpu_list('offline');
}

=head2 get_present_cpus

 my @cpus = get_present_cpus();

Returns the list of present CPU numbers, from
C</sys/devices/system/cpu/present>. These are the CPUs that the system
has, online or offline.

=cut

sub get_present_cpus {
    return _read_cpu_list('present');
}

=head2 get_cpu_topology

 my $topology = get_cpu_topology([$info]);

Returns a hash reference with the keys C<sockets>, C<cores_per_socket>,
C<threads_per_core> and C<numa_nodes>, from C<lscpu>. A value is undef if
C<lscpu> does not show it on this architecture (for example, s390x shows
sockets per book instead of sockets).

=cut

sub get_cpu_topology {
    my ($info) = @_;
    $info //= lscpu_info();

    return {
        sockets => $info->{'Socket(s)'},
        cores_per_socket => $info->{'Core(s) per socket'},
        threads_per_core => $info->{'Thread(s) per core'},
        numa_nodes => $info->{'NUMA node(s)'},
    };
}

sub _parse_cpu_map {
    my ($text) = @_;
    my %map;

    for my $line (split /\n/, $text // '') {
        next if $line =~ /^#/;
        my ($cpu, $socket, $node, $online) = split /,/, $line, -1;
        next unless defined $cpu && $cpu =~ /^\d+$/;
        $map{$cpu} = {
            socket => ($socket // '') eq '' ? undef : $socket,
            node => ($node // '') eq '' ? undef : $node,
            online => ($online // '') eq 'Y' ? 1 : 0,
        };
    }
    return \%map;
}

=head2 get_cpu_map

 my $map = get_cpu_map();

Returns a hash reference of the CPU number to a hash reference with the
keys C<socket>, C<node> (NUMA node) and C<online> (1 or 0), from
C<lscpu -a -p>. Offline CPUs are included. C<socket> or C<node> is undef
if C<lscpu> does not show it, for example C<node> on a system without
NUMA.

Use it to group per-CPU values by socket or NUMA node:

 my $map = get_cpu_map();
 my %sockets = map { $map->{$_}{socket} => 1 } grep { $map->{$_}{online} } keys %$map;

=cut

sub get_cpu_map {
    return _parse_cpu_map(script_output('LC_ALL=C lscpu -a -p=CPU,SOCKET,NODE,ONLINE'));
}

=head2 get_cpu_flags

 my @flags = get_cpu_flags([$info]);

Returns the list of CPU flags, from the C<lscpu> C<Flags> field. Returns an
empty list if C<lscpu> shows no flags.

=cut

sub get_cpu_flags {
    my ($info) = @_;
    $info //= lscpu_info();

    return split(' ', $info->{Flags} // '');
}

=head2 has_cpu_flag

 has_cpu_flag($flag, [$info]);

Returns true if the CPU has the flag C<$flag>, for example C<arch_perfmon>.

=cut

sub has_cpu_flag {
    my ($flag, $info) = @_;

    return scalar grep { $_ eq $flag } get_cpu_flags($info);
}

sub _parse_cpu_vulnerabilities {
    my ($text) = @_;
    my %vulns;

    for my $line (split /\n/, $text // '') {
        next unless $line =~ m{/vulnerabilities/([^/:]+):(.*)$};
        $vulns{$1} = $2;
    }
    return \%vulns;
}

=head2 get_cpu_vulnerabilities

 my $vulns = get_cpu_vulnerabilities();

Reads the files in C</sys/devices/system/cpu/vulnerabilities/> on the SUT
and returns a hash reference of vulnerability name to status, for example
C<< { retbleed => 'Mitigation: IBRS' } >>. Returns an empty hash reference
if the directory does not exist.

=cut

sub get_cpu_vulnerabilities {
    my $out = script_output('grep -H . /sys/devices/system/cpu/vulnerabilities/* 2>/dev/null', proceed_on_failure => 1);
    return _parse_cpu_vulnerabilities($out);
}

=head2 has_hw_pmu

 has_hw_pmu();

Checks whether a hardware Performance Monitoring Unit (PMU) is available,
with C<perf stat -e cycles>. The C<perf> package must be installed.

Returns true if the C<cycles> hardware event is counted. Returns false if
it is not supported or not counted, for example in a virtual machine
without a virtual PMU.

=cut

sub has_hw_pmu {
    my $out = script_output('perf stat -e cycles true 2>&1', proceed_on_failure => 1);
    return $out !~ /not supported|not counted/;
}

=head2 nmi_count

 my $count = nmi_count();

Returns the sum of the C<NMI> counters of all CPUs from
C</proc/interrupts>. Returns 0 if there is no C<NMI> line.

The meaning of the C<NMI> line is architecture specific: on x86_64 it
includes the PMU interrupts, but on ppc64le it counts System Reset
interrupts and on s390x Machine Check interrupts.

=cut

sub nmi_count {
    my $snapshot = get_interrupts();
    return 0 unless $snapshot->{irqs}{NMI};
    return get_irq_total($snapshot, 'NMI');
}

1;

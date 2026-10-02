# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Check device interrupt delivery during I/O on a multi-socket system.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use Mojo::JSON 'decode_json';
use LTP::utils 'check_kernel_taint';
use Kernel::cpu qw(lscpu_info get_cpu_model get_cpu_map has_cpu_flag);
use Kernel::irq qw(get_interrupts get_irq_total get_irq_per_cpu get_irq_remapped get_irqs_in_use get_device_irqs);
use Kernel::block_dev qw(is_block_device record_storage_info get_block_dev_kernel_name get_block_dev_pci_device);

my $logs = '/var/log/irq-delivery-storage';

# Pin one reader to each online CPU. Direct reads exercise the controller
# without changing the disk contents or relying on the page cache.
# TODO: consider a fio library when more tests run fio.
sub run_fio {
    my ($disk, $duration, $max_latency_ms, @cpus) = @_;
    my $output = "$logs/fio-$disk->{name}.json";
    assert_script_run("fio --name=irq-delivery-storage --filename=$disk->{dev} --readonly --allow_file_create=0 "
          . '--rw=randread --direct=1 --ioengine=libaio --bs=4k --iodepth=16 --size=1G '
          . '--numjobs=' . scalar(@cpus) . ' --cpus_allowed=' . join(',', @cpus) . ' --cpus_allowed_policy=split '
          . "--runtime=$duration --time_based --output-format=json --output=$output",
        timeout => $duration + 120);
    my $jobs = decode_json(script_output("cat $output"))->{jobs} // [];
    die "fio did not report all CPU workers on $disk->{name}" unless @$jobs == @cpus;
    die "A fio worker completed no reads on $disk->{name}" if grep { $_->{read}{total_ios} == 0 } @$jobs;

    # A lost interrupt can be hidden by the driver: after its timeout (30 s
    # for NVMe), it completes the request without an error. Such a read has
    # a completion latency of seconds instead of milliseconds. With
    # cpus_allowed_policy=split, worker N runs on the Nth CPU of the list.
    my @latency_ms = map { $_->{read}{clat_ns}{max} / 1e6 } @$jobs;
    my ($slowest) = sort { $latency_ms[$b] <=> $latency_ms[$a] } 0 .. $#latency_ms;
    my $worst = sprintf('worker %d on CPU %d: %.1f ms', $slowest, $cpus[$slowest], $latency_ms[$slowest]);
    record_info("Read latency $disk->{name}", "Maximum completion latency: $worst");
    die "Read completion latency on $disk->{name} above $max_latency_ms ms, $worst" if $latency_ms[$slowest] > $max_latency_ms;
}

sub io_error_count {
    my ($kernel_name) = @_;
    return script_output("dmesg | grep -c 'I/O error, dev $kernel_name,' || true");
}

# Check that a disk is usable and find the interrupts of its controller
sub prepare_disk {
    my ($dev) = @_;
    die "Use an absolute device path without shell metacharacters: $dev" unless $dev =~ m{^/dev/[A-Za-z0-9_./:-]+$};
    is_block_device($dev);
    my $name = get_block_dev_kernel_name($dev);
    assert_script_run("test ! -e /sys/class/block/$name/partition", fail_message => "$dev is a partition");
    assert_script_run("test \$(blockdev --getsize64 $dev) -ge 1073741824", fail_message => "$dev is smaller than 1 GiB");
    my $controller = get_block_dev_pci_device($dev);
    my @irqs = get_device_irqs($controller);
    record_info("Controller $name", "$dev\n$controller\nIRQs: " . join(',', @irqs));
    return {dev => $dev, name => $name, controller => $controller, irqs => \@irqs};
}

sub test_disk {
    my ($self, $disk, $info, $map, $duration, $max_latency_ms, @cpus) = @_;
    my $before = get_interrupts();
    # A driver can reserve more interrupts than it uses
    my @irqs = get_irqs_in_use($before, @{$disk->{irqs}});
    die "No interrupt of $disk->{name} is in use" unless @irqs;
    record_info("IRQs in use $disk->{name}", scalar(@irqs) . ' of ' . scalar(@{$disk->{irqs}}) . ': ' . join(',', @irqs));

    # Interrupt delivery through interrupt remapping on x2APIC machines has
    # broken before. Show if this run went through that path.
    my $remapped = get_irq_remapped($before, @irqs);
    my $remapped_count = grep { $_ } values %$remapped;
    record_info("Interrupt mode $disk->{name}", 'x2APIC offered by the CPU: ' . (has_cpu_flag('x2apic', $info) ? 'yes' : 'no')
          . "\nRemapped controller IRQs: $remapped_count of " . scalar(@irqs));

    my $io_errors = io_error_count($disk->{name});
    run_fio($disk, $duration, $max_latency_ms, @cpus);
    my $after = get_interrupts();

    # Report the distribution per socket and NUMA node, but do not require it
    # to be even
    my ($cpu_before, $cpu_after) = (get_irq_per_cpu($before, @irqs), get_irq_per_cpu($after, @irqs));
    for my $level (qw(socket node)) {
        my %delta;
        $delta{$map->{$_}{$level} // 'unknown'} += $cpu_after->{$_} - ($cpu_before->{$_} // 0) for keys %$cpu_after;
        record_info("IRQ per $level $disk->{name}", join("\n", map { "$level $_: $delta{$_}" } sort keys %delta));
    }

    my $delta = get_irq_total($after, @irqs) - get_irq_total($before, @irqs);
    die "No new controller interrupts during direct I/O on $disk->{name}" unless $delta > 0;
    die "New I/O errors on $disk->{name}" if io_error_count($disk->{name}) > $io_errors;
    check_kernel_taint($self);
    record_info("I/O passed $disk->{name}", scalar(@cpus) . " CPU workers completed reads; $delta new controller interrupts");
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $info = lscpu_info();
    my $map = get_cpu_map();
    my @cpus = sort { $a <=> $b } grep { $map->{$_}{online} } keys %$map;
    my %sockets = map { ($map->{$_}{socket} // 'unknown') => 1 } @cpus;
    record_info('CPU topology', (get_cpu_model($info) // 'unknown') . "\nonline CPUs: " . join(',', @cpus)
          . "\nsockets with online CPUs: " . join(',', sort keys %sockets));
    die 'This scenario requires more than eight online CPUs on at least two sockets'
      unless @cpus > 8 && keys(%sockets) >= 2 && !$sockets{unknown};

    my @devs = split ' ', get_required_var('IRQ_DELIVERY_DEVICE');
    die 'IRQ_DELIVERY_DEVICE has no device' unless @devs;
    my $duration = get_var('IRQ_DELIVERY_DURATION', 30);
    die 'IRQ_DELIVERY_DURATION must be a positive integer' unless $duration =~ /^[1-9]\d*$/;
    my $max_latency_ms = get_var('IRQ_DELIVERY_MAX_LATENCY_MS', 1000);
    die 'IRQ_DELIVERY_MAX_LATENCY_MS must be a positive integer' unless $max_latency_ms =~ /^[1-9]\d*$/;

    # Check all disks first, so that a configuration error fails before the
    # workload runs
    record_storage_info();
    my @disks = map { prepare_disk($_) } @devs;
    my %seen;
    die "Disk $_->{name} is selected more than once" for grep { $seen{$_->{name}}++ } @disks;

    install_package('fio', trup_apply => 1);
    assert_script_run("mkdir -p $logs");
    # Test one disk at a time, so that the counters belong to one controller
    $self->test_disk($_, $info, $map, $duration, $max_latency_ms, @cpus) for @disks;
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    script_run("mkdir -p $logs; cat /proc/interrupts > $logs/interrupts.txt; dmesg > $logs/dmesg.txt");
    upload_logs("$logs/$_", failok => 1) for split ' ', script_output("ls $logs 2>/dev/null", proceed_on_failure => 1);
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

Exercise PCI storage interrupts on a system with more than eight online
CPUs on at least two sockets. For each selected disk, run one
direct-read fio worker per online CPU. Each worker must complete reads
without a read that takes longer than C<IRQ_DELIVERY_MAX_LATENCY_MS>,
the interrupt count of the disk's controller must increase, no new I/O
errors may be logged for the disk and the kernel must not be tainted (see
C<check_kernel_taint> in C<LTP::utils>).

The test records the new interrupts per socket and per NUMA node, but does
not require equal interrupt distribution, activity on every CPU, or activity
on every queue.
These are not requirements for working interrupt delivery. A pass is a
smoke-test result, not proof that the original regression can be
reproduced on this controller.

=head1 Configuration

=head2 IRQ_DELIVERY_DEVICE

Required whole-disk device paths, separated by spaces, preferably under
C</dev/disk/by-id/>. Select local PCI storage such as NVMe or a disk behind
a SATA controller. The test checks the disks one after another, each with
its own workload. Each disk must have at least 1 GiB. The workload only
reads the disks. Loop devices, device mapper devices, and partitions are
not supported.

=head2 IRQ_DELIVERY_DURATION

Workload duration in seconds. Defaults to C<30>.

=head2 IRQ_DELIVERY_MAX_LATENCY_MS

Maximum read completion latency of each fio worker in milliseconds.
Defaults to C<1000>. A read that waits for a driver timeout, for example
after a lost interrupt, takes seconds. Healthy local storage completes
reads within a few milliseconds.

=head2 LTP_TAINT_EXPECTED

Mask of the kernel taint flags that are expected and do not fail the test.
See C<check_kernel_taint> in C<LTP::utils>.

=cut

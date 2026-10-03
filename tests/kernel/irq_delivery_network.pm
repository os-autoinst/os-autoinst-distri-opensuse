# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Check network card interrupt delivery during traffic on a multi-socket system.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use lockapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';
use Mojo::JSON 'decode_json';
use List::Util qw(max sum0);
use LTP::utils 'check_kernel_taint';
use Kernel::cpu qw(lscpu_info get_cpu_model get_cpu_map has_cpu_flag);
use Kernel::irq qw(get_interrupts get_irq_total get_irq_per_cpu get_irq_remapped get_irqs_in_use get_device_irqs
  get_irq_affinity set_irq_affinity);
use Kernel::net_tests qw(get_net_dev_pci_device set_link_up has_ipv4_addr wait_for_ipv4_addr add_ipv4_addr get_net_prefix_len);
use Kernel::multimachine_topology qw(get_local_node get_node_by_role get_node_interface get_topology_network require_field);

my $logs = '/var/log/irq-delivery-network';
my $first_port = 5201;

# The interface of a node on the test network is its first interface
sub test_interface {
    my ($node) = @_;
    my $interface = get_node_interface($node, 0);
    require_field($interface->{id}, "multimachine_topology interface id missing for node '$node->{id}'");
    require_field($interface->{ipv4}, "multimachine_topology ipv4 missing for interface $interface->{id} of node '$node->{id}'");
    return $interface;
}

# Bring the test interface up and make sure that it has its address. A
# static address is set by the test; any other address comes from the lab
# network, for example from DHCP.
sub setup_interface {
    my ($node, $interface) = @_;
    set_link_up($interface->{id});
    if ($interface->{static} && !has_ipv4_addr($interface->{id}, $interface->{ipv4})) {
        my $network = get_topology_network($interface->{network});
        my $cidr = require_field($network->{ipv4_cidr}, "ipv4_cidr missing for network '$network->{id}'");
        my $plen = get_net_prefix_len(net => $cidr) // die "No prefix length in $cidr";
        add_ipv4_addr(ip => $interface->{ipv4}, dev => $interface->{id}, plen => $plen);
    }
    wait_for_ipv4_addr($interface->{id}, $interface->{ipv4});
    record_info('Network', "$node->{id} ($node->{role}): $interface->{id} $interface->{ipv4}");
}

# Check that an interface is usable and find the interrupts of its card
sub prepare_nic {
    my ($name) = @_;
    die "Use a network interface name: $name" unless $name =~ /^[A-Za-z0-9_.:-]{1,15}$/;
    assert_script_run("test -e /sys/class/net/$name", fail_message => "Network interface $name not found");
    # A network driver requests its interrupts only when the interface is up
    # (IFF_UP, bit 0 of the interface flags)
    assert_script_run("test \$((\$(cat /sys/class/net/$name/flags) & 1)) = 1", fail_message => "Network interface $name is not up");
    my $card = get_net_dev_pci_device($name);
    my @irqs = get_device_irqs($card);
    record_info("Card $name", "$card\nIRQs: " . join(',', @irqs));
    return {name => $name, card => $card, irqs => \@irqs};
}

# A transmit queue timeout is counted per queue, see dev_watchdog() in the
# kernel
sub tx_timeouts {
    my ($nic) = @_;
    return sum0(split ' ', script_output("cat /sys/class/net/$nic->{name}/queues/tx-*/tx_timeout"));
}

# Assign each interrupt one CPU, taking the CPUs of the sockets in turn, so
# that every socket gets interrupts
sub spread_over_sockets {
    my ($map, $cpus, @irqs) = @_;
    my %by_socket;
    push @{$by_socket{$map->{$_}{socket}}}, $_ for @$cpus;
    my @sockets = sort { $a <=> $b } keys %by_socket;
    my @order;
    for my $i (0 .. max(map { $#{$by_socket{$_}} } @sockets)) {
        push @order, grep { defined } map { $by_socket{$_}[$i] } @sockets;
    }
    my $n = 0;
    return map { $_ => $order[$n++ % @order] } @irqs;
}

sub run_peer {
    my ($self, $node, $streams) = @_;
    my $ip = test_interface($node)->{ipv4};
    my $last_port = $first_port + $streams - 1;
    if (script_run('firewall-cmd --state') == 0) {
        assert_script_run("firewall-cmd --add-port=$first_port-$last_port/tcp");
    }
    assert_script_run("for port in \$(seq $first_port $last_port); do iperf3 --server --daemon --bind $ip --port \$port || exit 1; done");
    record_info('Servers', "$streams iperf3 servers on $ip, ports $first_port-$last_port");
    barrier_wait({name => 'IRQ_NET_PEER_READY', check_dead_job => 1});
    barrier_wait({name => 'IRQ_NET_TRAFFIC_DONE', check_dead_job => 1});
    script_run('pkill -x iperf3');
    check_kernel_taint($self);
}

# Pin one stream to each CPU. Every second CPU receives instead of sending,
# so that both directions of the card get traffic.
# TODO: temporary limit of the bitrate of each stream, because the test
# link is the shared lab network; remove it with poo#207927.
sub run_streams {
    my ($local_ip, $peer_ip, $duration, @cpus) = @_;
    assert_script_run("i=0; for cpu in @cpus; do r=''; [ \$((i % 2)) = 1 ] && r=--reverse; "
          . "taskset -c \$cpu iperf3 --client $peer_ip --bind $local_ip --port \$(($first_port + i)) --time $duration "
          . "--bitrate 1M --interval 0 --json \$r > $logs/iperf-\$cpu.json 2>&1 & i=\$((i + 1)); done; wait",
        timeout => $duration + 120);
    my $total = 0;
    for my $cpu (@cpus) {
        my $output = script_output("cat $logs/iperf-$cpu.json");
        my $result = eval { decode_json($output) } // die "Stream on CPU $cpu did not report a result: " . (split /\n/, $output)[0];
        die "Stream on CPU $cpu failed: $result->{error}" if $result->{error};
        my $received = $result->{end}{sum_received} // {};
        die "Stream on CPU $cpu moved no data" unless ($result->{end}{sum_sent}{bytes} // 0) > 0 && ($received->{bytes} // 0) > 0;
        $total += $received->{bits_per_second} // 0;
    }
    record_info('Streams', sprintf('%d streams, %.1f Gbit/s in total', scalar(@cpus), $total / 1e9));
}

sub run_sut {
    my ($self, $node, $streams, $duration) = @_;
    my $info = lscpu_info();
    my $map = get_cpu_map();
    my @cpus = sort { $a <=> $b } grep { $map->{$_}{online} } keys %$map;
    my %sockets = map { ($map->{$_}{socket} // 'unknown') => 1 } @cpus;
    record_info('CPU topology', (get_cpu_model($info) // 'unknown') . "\nonline CPUs: " . join(',', @cpus)
          . "\nsockets with online CPUs: " . join(',', sort keys %sockets));
    die 'This scenario requires more than eight online CPUs on at least two sockets'
      unless @cpus > 8 && keys(%sockets) >= 2 && !$sockets{unknown};
    my @online = @cpus;
    if (@cpus > $streams) {
        record_info('Streams', "Only the first $streams of " . scalar(@cpus) . ' CPUs get a stream, see IRQ_DELIVERY_STREAMS');
        splice @cpus, $streams;
    }

    my $interface = test_interface($node);
    my $peer_ip = test_interface(get_node_by_role('peer'))->{ipv4};
    my $nic = prepare_nic($interface->{id});
    assert_script_run("mkdir -p $logs");
    barrier_wait({name => 'IRQ_NET_PEER_READY', check_dead_job => 1});

    my $current = get_interrupts();
    # A driver can reserve more interrupts than it uses
    my @irqs = get_irqs_in_use($current, @{$nic->{irqs}});
    die "No interrupt of $nic->{name} is in use" unless @irqs;
    my %in_use = map { $_ => 1 } @irqs;
    my @unused = grep { !$in_use{$_} } @{$nic->{irqs}};
    record_info("IRQs in use $nic->{name}", scalar(@irqs) . ' of ' . scalar(@{$nic->{irqs}}) . ': ' . join(',', @irqs)
          . "\nReserved, but not in use: " . (join(',', @unused) || 'none'));
    # Interrupt delivery through interrupt remapping on x2APIC machines has
    # broken before. Show if this run went through that path.
    my $remapped = get_irq_remapped($current, @irqs);
    my $remapped_count = grep { $_ } values %$remapped;
    record_info("Interrupt mode $nic->{name}", 'x2APIC offered by the CPU: ' . (has_cpu_flag('x2apic', $info) ? 'yes' : 'no')
          . "\nRemapped card IRQs: $remapped_count of " . scalar(@irqs));

    # Spread the queue interrupts over all sockets and stop irqbalance
    # during the traffic, see the description.
    # TODO: check this with the Intel cards and the Mellanox cards in
    # Ethernet mode of the lab machines, with poo#207927; their drivers can
    # handle the queue interrupts differently.
    my $irqbalance = script_run('systemctl is-active --quiet irqbalance') == 0;
    assert_script_run('systemctl stop irqbalance') if $irqbalance;
    my $original = get_irq_affinity(@irqs);
    my %target = spread_over_sockets($map, \@online, @irqs);
    my @refused = set_irq_affinity(%target);
    die "The kernel refused the affinity of IRQs @refused of $nic->{name}" if @refused;
    record_info("IRQ affinity $nic->{name}", join("\n", map { "IRQ $_: CPU $target{$_} (socket $map->{$target{$_}}{socket})" } @irqs));
    my $timeouts = tx_timeouts($nic);

    my $before = get_interrupts();
    run_streams($interface->{ipv4}, $peer_ip, $duration, @cpus);
    my $after = get_interrupts();
    # Let the peer finish while this job checks the results
    barrier_wait({name => 'IRQ_NET_TRAFFIC_DONE', check_dead_job => 1});
    set_irq_affinity(%$original);
    assert_script_run('systemctl start irqbalance') if $irqbalance;

    # Every socket must receive interrupts, but the distribution does not
    # need to be even
    my ($cpu_before, $cpu_after) = (get_irq_per_cpu($before, @irqs), get_irq_per_cpu($after, @irqs));
    my %per;
    for my $level (qw(socket node)) {
        $per{$level}{$map->{$_}{$level} // 'unknown'} += $cpu_after->{$_} - ($cpu_before->{$_} // 0) for keys %$cpu_after;
        record_info("IRQ per $level $nic->{name}", join("\n", map { "$level $_: $per{$level}{$_}" } sort keys %{$per{$level}}));
    }

    my $delta = get_irq_total($after, @irqs) - get_irq_total($before, @irqs);
    die "No new card interrupts during the traffic on $nic->{name}" unless $delta > 0;
    my @silent = grep { !$per{socket}{$_} } sort keys %sockets;
    die "No new card interrupts on socket @silent of $nic->{name}" if @silent;
    my $new_timeouts = tx_timeouts($nic) - $timeouts;
    die "$new_timeouts transmit queue timeouts on $nic->{name}" if $new_timeouts > 0;
    # A transmit queue timeout also triggers a kernel warning, which taints
    # the kernel
    check_kernel_taint($self);
    record_info("Traffic passed $nic->{name}", scalar(@cpus) . " streams moved data; $delta new card interrupts");
}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    my $streams = get_var('IRQ_DELIVERY_STREAMS', 128);
    die 'IRQ_DELIVERY_STREAMS must be a positive integer' unless $streams =~ /^[1-9]\d*$/;
    my $duration = get_var('IRQ_DELIVERY_DURATION', 30);
    die 'IRQ_DELIVERY_DURATION must be a positive integer' unless $duration =~ /^[1-9]\d*$/;
    my $node = get_local_node();
    setup_interface($node, test_interface($node));
    install_package('iperf', trup_apply => 1);

    if ($node->{role} eq 'peer') {
        $self->run_peer($node, $streams);
    } elsif ($node->{role} eq 'sut') {
        $self->run_sut($node, $streams, $duration);
    } else {
        die "Unknown role '$node->{role}' of node $node->{id}, use sut or peer";
    }
}

sub post_fail_hook {
    my ($self) = @_;
    select_serial_terminal;
    script_run("mkdir -p $logs; cat /proc/interrupts > $logs/interrupts.txt; dmesg > $logs/dmesg.txt; ip -s link > $logs/ip-link.txt");
    upload_logs("$logs/$_", failok => 1) for split ' ', script_output("ls $logs 2>/dev/null", proceed_on_failure => 1);
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

Exercise network card interrupts on a system with more than eight online
CPUs on at least two sockets. The test needs two machines,
described in C<multimachine_topology> (see C<Kernel::multimachine_topology>):

=over

=item * The C<peer> node starts one iperf3 server per stream on its test
interface and waits until the traffic is done.

=item * The C<sut> node pins one iperf3 stream to each online CPU, up to
C<IRQ_DELIVERY_STREAMS>. Every second stream receives instead of sending,
so that both directions of the card get traffic.

=back

The kernel does not manage the queue interrupts of a network card, so the
C<sut> spreads them over all sockets before the traffic: each interrupt
runs on one CPU, taking the CPUs of the sockets in turn. irqbalance is
stopped during the traffic, and the original affinity is restored after
it.

On the C<sut>, each stream must move data in both directions, the
interrupt count of the card must increase on every socket, no transmit
queue of the card may time out, and the kernel must not be tainted. A
transmit queue timeout, as seen with the original regression, also
triggers a kernel warning. The test records the new interrupts per socket
and per NUMA node, but does not require an even distribution. The
C<peer> only checks that its kernel is not tainted.

The test interface of a node is its first interface in the topology, and
it needs an C<ipv4> address there. Both nodes bring their test interface
up first. If the interface is C<static> in the topology, the test adds the
address with the prefix length of its network; otherwise the address comes
from the lab network, for example from DHCP, and the test waits for it.
Create the barriers C<IRQ_NET_PEER_READY> and C<IRQ_NET_TRAFFIC_DONE> with
C<multimachine_barriers> first.

=head1 Configuration

=head2 ROLE

The role of the local node in C<multimachine_topology>: C<sut> or C<peer>.

=head2 IRQ_DELIVERY_DURATION

Traffic duration in seconds. Defaults to C<30>.

=head2 IRQ_DELIVERY_STREAMS

Maximum number of streams, one per CPU of the C<sut>. Defaults to C<128>.
Both nodes must use the same value: the C<peer> starts one server per
stream.

=head2 LTP_TAINT_EXPECTED

Mask of the kernel taint flags that are expected and do not fail the test.
See C<check_kernel_taint> in C<LTP::utils>.

=cut

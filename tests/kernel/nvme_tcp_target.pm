# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Export a disk over NVMe/TCP for the initiators of the topology
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use mm_network 'setup_static_mm_network';
use Kernel::nvme qw(nvmet_target_create nvmet_target_delete);
use Kernel::net_tests 'get_net_prefix_len';
use Kernel::multimachine_topology qw(get_local_node get_node_interface get_topology_network);

sub run {
    my $nqn = get_var('NVMET_SUBSYS_NQN', 'nqn.2026-10.de.openqa:nvmet-tcp');
    my $device = get_var('NVMET_DEVICE', '/dev/vdb');
    my $port = get_var('NVMET_PORT', 4420);
    my $interface = get_node_interface(get_local_node(), 0);
    my $ip = $interface->{ipv4};

    select_serial_terminal;
    if (check_var('NICTYPE', 'tap')) {
        my $prefix = get_net_prefix_len(net => get_topology_network($interface->{network})->{ipv4_cidr});
        setup_static_mm_network("$ip/$prefix");
    }

    nvmet_target_delete(nqn => $nqn);
    nvmet_target_create(nqn => $nqn, device => $device, addr => $ip, port => $port);
    barrier_wait({name => 'NVME_TARGET_READY', check_dead_job => 1});
    barrier_wait({name => 'NVME_TEST_DONE', check_dead_job => 1});
    nvmet_target_delete(nqn => $nqn);
}

sub post_fail_hook {
    select_serial_terminal;
    script_run('find /sys/kernel/config/nvmet -maxdepth 3');
    script_run('dmesg | grep -i nvme | tail -50');
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

Export C<NVMET_DEVICE> as namespace 1 of the subsystem C<NVMET_SUBSYS_NQN>
over NVMe/TCP, on the IPv4 address that the C<multimachine_topology> gives
to this node. Any host can connect. Then wait until the initiators are
done and remove the target again.

With C<NICTYPE=tap> (QEMU), set the address of the topology as a static
address, because the multimachine network has no DHCP server.

Run C<kernel/multimachine_barriers> first, with the barriers
C<NVME_TARGET_READY> and C<NVME_TEST_DONE>.

=head1 Configuration

=head2 NVMET_SUBSYS_NQN

Optional. Subsystem NQN. Default: C<nqn.2026-10.de.openqa:nvmet-tcp>.

=head2 NVMET_DEVICE

Optional. Block device to export. All data on it is lost.
Default: C</dev/vdb>, the second disk of a QEMU job.

=head2 NVMET_PORT

Optional. TCP port of the target. Default: C<4420>.

=cut

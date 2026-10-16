# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Connect to the NVMe/TCP target of the topology and do I/O
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use package_utils 'install_package';
use mm_network 'setup_static_mm_network';
use Kernel::nvme qw(nvme_discover nvme_connect nvme_disconnect);
use Kernel::net_tests 'get_net_prefix_len';
use Kernel::multimachine_topology qw(get_local_node get_node_by_role get_node_interface get_topology_network);

sub run {
    my $nqn = get_var('NVMET_SUBSYS_NQN', 'nqn.2026-10.de.openqa:nvmet-tcp');
    my $port = get_var('NVMET_PORT', 4420);
    my $interface = get_node_interface(get_local_node(), 0);
    my $target_ip = get_node_interface(get_node_by_role('nvme_target'), 0)->{ipv4};

    select_serial_terminal;
    if (check_var('NICTYPE', 'tap')) {
        my $prefix = get_net_prefix_len(net => get_topology_network($interface->{network})->{ipv4_cidr});
        setup_static_mm_network("$interface->{ipv4}/$prefix");
    }

    install_package('nvme-cli', trup_apply => 1);
    nvme_disconnect($nqn, may_fail => 1);
    barrier_wait({name => 'NVME_TARGET_READY', check_dead_job => 1});

    record_info('discover', nvme_discover(addr => $target_ip, port => $port));
    my $ns = nvme_connect(nqn => $nqn, addr => $target_ip, port => $port);
    record_info('subsystem', script_output("nvme list-subsys /dev/$ns"));

    assert_script_run('dd if=/dev/urandom of=/tmp/nvme_tcp_data bs=1M count=16');
    assert_script_run("dd if=/tmp/nvme_tcp_data of=/dev/$ns bs=1M oflag=direct");
    assert_script_run("cmp -n 16M /tmp/nvme_tcp_data /dev/$ns");

    nvme_disconnect($nqn);
    barrier_wait({name => 'NVME_TEST_DONE', check_dead_job => 1});
}

sub post_fail_hook {
    select_serial_terminal;
    script_run('nvme list-subsys');
    script_run('dmesg | grep -i nvme | tail -50');
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Description

Connect over NVMe/TCP to the subsystem C<NVMET_SUBSYS_NQN> on the node with
the role C<nvme_target> of the C<multimachine_topology>. Write 16 MiB to the
namespace, read the data back and compare it, then disconnect.

With C<NICTYPE=tap> (QEMU), set the address of the topology as a static
address, because the multimachine network has no DHCP server.

Run C<kernel/multimachine_barriers> first, with the barriers
C<NVME_TARGET_READY> and C<NVME_TEST_DONE>.

B<Warning:> the test overwrites the start of the exported namespace.

=head1 Configuration

=head2 NVMET_SUBSYS_NQN

Optional. Subsystem NQN to connect. Must match C<kernel/nvme_tcp_target>.
Default: C<nqn.2026-10.de.openqa:nvmet-tcp>.

=head2 NVMET_PORT

Optional. TCP port of the target. Default: C<4420>.

=cut

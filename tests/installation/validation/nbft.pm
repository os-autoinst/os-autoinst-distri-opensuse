# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the root file system is on the NVMe/TCP namespace of the NBFT
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    my $nqn = get_var('NVMET_SUBSYS_NQN', 'nqn.2026-10.de.openqa:nvmet-tcp');
    my $ip = get_var('NVMET_PORT_IP', '10.0.2.1');

    assert_script_run('ls /sys/firmware/acpi/tables/NBFT*', fail_message => 'No NBFT ACPI table');
    record_info('NBFT', script_output('nvme nbft show'));
    record_info('nvme', script_output('rpm -q nvme-cli libnvme1 || true') . "\n" . script_output('nvme version'));

    my $root = script_output('findmnt -n -o SOURCE / | sed "s/\[.*\]//"');
    my $disk = script_output("lsblk -n -o PKNAME $root");
    record_info('root', "/ is on $root, disk $disk");
    assert_script_run("nvme list-subsys /dev/$disk | tee /tmp/subsys.txt");
    assert_script_run("grep -q '$nqn' /tmp/subsys.txt", fail_message => "/ is not on subsystem $nqn");
    assert_script_run("grep -q 'tcp traddr=$ip' /tmp/subsys.txt", fail_message => "/ is not on NVMe/TCP to $ip");

    if (script_run('coredumpctl --no-pager list nvme') == 0) {
        record_info('coredump', script_output('coredumpctl --no-pager info nvme', proceed_on_failure => 1), result => 'fail');
        die 'nvme dumped core';
    }
}

sub post_fail_hook {
    select_serial_terminal;
    script_run('nvme list-subsys');
    script_run('journalctl -b --no-pager | grep -i -E "nvme|nbft" | tail -100');
}

1;

=head1 Description

Run after the first boot of a system that was installed with the root file
system on the NVMe/TCP namespace that an NBFT ACPI table describes. Check
that the NBFT exists, that C</> is on the subsystem C<NVMET_SUBSYS_NQN>
over TCP to C<NVMET_PORT_IP>, and that C<nvme> did not dump core
(bsc#1283955).

=head1 Configuration

=head2 NVMET_SUBSYS_NQN

Optional. Expected subsystem NQN. Default:
C<nqn.2026-10.de.openqa:nvmet-tcp>.

=head2 NVMET_PORT_IP

Optional. Expected target address. Default: C<10.0.2.1>.

=cut

# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check the Azure accelerated networking NIC driver (MANA or Mellanox)
# PUBLIC_CLOUD_ACCNET: mana requires MANA hardware, mlx5 is skipped on other hardware, any accepts either.
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::ssh_interactive 'select_host_console';
use version_utils 'is_sle';

my %nic = (
    mana => {pci_attr => 'device', pci_id => '0x00ba', driver => 'mana'},
    mlx5 => {pci_attr => 'vendor', pci_id => '0x15b3', driver => 'mlx5_core'},
);

sub run {
    my ($self, $args) = @_;
    select_host_console();
    my $instance = $args->{my_instance};

    my $type = get_required_var('PUBLIC_CLOUD_ACCNET');
    die "PUBLIC_CLOUD_ACCNET must be 'mana', 'mlx5' or 'any', got '$type'" unless ($type =~ /^(mana|mlx5|any)$/);
    die 'MANA is supported on SLES 15-SP5 and newer only' if ($type eq 'mana' && is_sle('<15-SP5'));

    record_info('Kernel', $instance->ssh_script_output('uname -r'));
    record_info('Network', $instance->ssh_script_output('ip -o link show'));
    record_info('PCI', $instance->ssh_script_output('for d in /sys/bus/pci/devices/*; do echo "$(basename $d) $(cat $d/vendor) $(cat $d/device) $(basename "$(readlink $d/driver)")"; done'));

    # bsc#1276748: eth0 must keep its IPv4 address and route after the first boot
    $instance->ssh_assert_script_run('ip -4 -o addr show dev eth0 scope global | grep -q inet');
    $instance->ssh_assert_script_run('ip -4 route show default dev eth0 | grep -q default');

    # Older sizes and Arm sizes can land on either hardware, so only 'mana' dies on other hardware
    my ($hw) = grep { $instance->ssh_script_run("grep -qx $nic{$_}->{pci_id} /sys/bus/pci/devices/*/$nic{$_}->{pci_attr}") == 0 } ($type eq 'any' ? qw(mana mlx5) : $type);
    unless ($hw) {
        return record_info('Skipped', "No $type PCI device found, the VM runs on different NIC hardware") if ($type eq 'mlx5');
        die "No $type PCI device found";
    }
    record_info('NIC', "The VM runs on $hw hardware");

    my $driver = $nic{$hw}->{driver};
    $instance->ssh_assert_script_run("lsmod | grep -qw $driver || grep -q '/$driver\\.ko' /lib/modules/\$(uname -r)/modules.builtin");
    # The VF is a lower device of the eth0 netvsc, its name differs between SLE versions (eth1 or enP*)
    $instance->ssh_assert_script_run('basename -a $(readlink /sys/class/net/eth0/lower_*/device/driver) | grep -qx ' . $driver);
    # Informational only, the aarch64 kernels do not ship the mana driver
    record_info('mana driver', $instance->ssh_script_run('modinfo mana > /dev/null') == 0 ? 'The mana driver is available' : 'The mana driver is not available') if ($type eq 'any');
}

1;

# SUSE's openQA tests#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Preparation before provisioning NFS setup
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use serial_terminal "select_serial_terminal";
use utils;
use lockapi;

sub prepare_bond {
    my $cfg = " /etc/sysconfig/network/ifcfg-bond0";
    my $nfs_if1 = get_required_var('NFS_IF_1');
    my $nfs_if2 = get_required_var('NFS_IF_2');
    my $nfs_bond_ip = get_required_var('NFS_BOND_IP');
    my $bond_mode = get_var('BOND_MODE', '802.3ad');

    assert_script_run("curl -s -o $cfg " . data_url("kernel/ifcfg-bond0"));
    file_content_replace($cfg, 'IPv4_ADDRESS' => $nfs_bond_ip);
    file_content_replace($cfg, 'BOND_DEVICE_1' => $nfs_if1);
    file_content_replace($cfg, 'BOND_DEVICE_2' => $nfs_if2);
    file_content_replace($cfg, 'BONDING_MODE' => $bond_mode);

    assert_script_run("ip link set up dev $nfs_if1");
    assert_script_run("ip link set up dev $nfs_if2");

    my $out = script_output("wicked show-config");
    record_info('show-config', $out);
    die "unable to find bond0 in wicked show-config!" unless $out =~ /bond0/;
    assert_script_run("wicked ifup all bond0");
}



sub run {
    my ($self) = @_;
    my $role = get_required_var('ROLE');

    select_serial_terminal;
    systemctl 'stop ' . $self->firewall;
    set_hostname(get_var("HOSTNAME", "susetest"));

    prepare_bond if get_var('NFS_BOND') == "1";
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}
sub post_run_hook { }

1;

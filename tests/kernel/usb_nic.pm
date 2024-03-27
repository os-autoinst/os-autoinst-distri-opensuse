# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: usb_nic
# Summary: Simple smoke test for testing USB NIC connected to system
# Maintainer: LSG QE Kernel <kernel-qa@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = @_;

    select_serial_terminal;

    my $interface = script_output 'basename $(readlink /sys/class/net/* | grep usb )';

    assert_script_run "echo \"BOOTPROTO='dhcp'\" > /etc/sysconfig/network/ifcfg-$interface";
    assert_script_run "echo \"STARTMODE='auto'\" >> /etc/sysconfig/network/ifcfg-$interface";

    systemctl("restart wicked.service", 300);

    my $ping_peer = script_output "ip route show dev $interface | cut -d ' ' -f 7";
    assert_script_run "ping -I $interface -c 4 $ping_peer";

    # DEBUG for bsc#1220838
    script_run("supportconfig", 300);
    assert_script_run("wget --quiet " . data_url("kernel/debug.sh") . " -O /usr/lib/systemd/system-shutdown/debug.sh");
    assert_script_run("chmod +x /usr/lib/systemd/system-shutdown/debug.sh");
}

sub test_flags {
    return {fatal => 0};
}

1;

# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: set configuration as glue
# Maintainer: Leon Guo <xguo@suse.com>

package set_config_as_glue;

use base "consoletest";
use virt_autotest::common;
use strict;
use warnings;
use testapi;

sub fufill_guests_in_setting {
    my $wait_script = "30";
    my $vm_types = "sles|win|opensuse|alp|oracle";
    my $get_vm_hostnames = "virsh list --all | grep -Ei \"${vm_types}\" | awk \'{print \$2}\'";
    my $vm_hostnames = script_output($get_vm_hostnames, $wait_script, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_array = split(/\n+/, $vm_hostnames);
    foreach (@vm_hostnames_array) {
        my $get_vm_macaddress = "virsh domiflist --domain $_ | grep -oE \"([0-9|a-z]{2}:){5}[0-9|a-z]{2}\"";
        my $vm_macaddress = script_output($get_vm_macaddress, $wait_script, type_command => 0, proceed_on_failure => 0);
        $virt_autotest::common::guests{$_}->{macaddress} = $vm_macaddress;
    }
}

sub run {
    fufill_guests_in_setting;
}

1;

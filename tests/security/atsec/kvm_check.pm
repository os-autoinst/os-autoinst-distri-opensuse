# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'kvm check' test case of ATSec test suite
# Maintainer: xiaojing.liu <xiaojing.liu@suse.com>
# Tags: poo#101956

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # Install the required packages
    zypper_call('in libvirt wget');

    # Upload the network xml file
    my $file = 'kvm_check_network.xml';
    assert_script_run 'wget --quiet ' . data_url("atsec/$file");

    # Define network by parsing xml file
    assert_script_run("virsh net-define $file");

    # Check if the xml file is parsed successfully
    validate_script_output 'virsh net-list --all | grep default', qr/default\s+inactive\s+no\s+yes/;

    assert_script_run('virsh net-start default');
    validate_script_output 'virsh net-list --all | grep default', qr/default\s+active\s+no\s+yes/;
}

sub test_flags {
    return {always_rollback => 1};
}

1;

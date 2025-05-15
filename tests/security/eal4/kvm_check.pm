# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'kvm check' test case of EAL4 test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#101956

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use eal4_test;

sub run {
    my ($self) = shift;
    my $test_log = "kvm_check_default.txt";

    select_console 'root-console';
    script_run('printf "# Starting kvm_check test #" >> ' . $test_log . '');

    # Install the required packages
    zypper_call('in libvirt');

    # Upload the network xml file
    my $file = 'kvm_check_network.xml';
    assert_script_run 'wget --quiet ' . data_url("eal4/$file");

    # Check if the 'default' already exists, if yes, then undefine it
    script_run('printf "# Check if the default already exists, if yes, then undefine it\n" >> ' . $test_log . '');
    script_run('printf "virsh net-list --all | grep default" >> ' . $test_log . '');
    my $exists_default_info = script_output('virsh net-list --all | grep default', proceed_on_failure => 1);

    if ($exists_default_info =~ /default\s+(\S+)\s+(\S+)\s+(\S+)/) {
        script_run('printf "\nvirsh net-destroy default\n"  >> ' . $test_log . '') if ($1 eq 'active');
        assert_script_run('virsh net-destroy default') if ($1 eq 'active');
        script_run('printf "\nvirsh net-undefine default\n" >> ' . $test_log . '');
        assert_script_run('virsh net-undefine default >> ' . $test_log . '');
    }

    # Define network by parsing xml file
    script_run('printf "\n# Define network by parsing xml file\n" >> ' . $test_log . '');
    script_run('printf "virsh net-define ' . $file . '\n" >> ' . $test_log . '');
    assert_script_run("virsh net-define $file ");

    # Check if the xml file is parsed successfully
    script_run('printf "\n# Check if the xml file is parsed successfully" >> ' . $test_log . '');
    script_run('printf "\nvirsh net-list --all | grep default\n" >> ' . $test_log . '');
    validate_script_output 'virsh net-list --all | grep default', qr/default\s+inactive\s+no\s+yes/;
    script_run('virsh net-list --all | grep default >> ' . $test_log . '');

    script_run('printf "\nvirsh net-start default\n" >> ' . $test_log . '');
    assert_script_run('virsh net-start default');
    script_run('printf "\nvirsh net-list --all | grep default\n" >> ' . $test_log . '');

    validate_script_output 'virsh net-list --all | grep default', qr/default\s+active\s+no\s+yes/;
    script_run('virsh net-list --all | grep default >> ' . $test_log . '');
    script_run('printf "\n# Ending kvm_check test #" >> ' . $test_log . '');

    upload_log_file($test_log);
}

sub test_flags {
    return {always_rollback => 1};
}

1;

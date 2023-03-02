# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This file does the necessary setup and checks for alp host to do virtualization test.
# Maintainer: alice <xlai@suse.com>, qe-virt@suse.de

package prepare_alp_host;
use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;

    # Validate that kernel-default is installed and kvm module is loaded.
    # Note: the alp host unattended installation will include kernel-default
    #       package installation. See poo#118939 for more details.
    assert_script_run(q@rpm -qa | grep kernel-default-[0-9]@);
    assert_script_run(q@lsmod |grep kvm@);
    record_info("KVM module is successfully loaded.");

    # Download alp vm ignition config files
    assert_script_run("mkdir -p /var/lib/libvirt/images");
    my $cmd = "curl -L "
      . data_url("virt_autotest/guest_unattended_installation_files/VIRT_TEST_VM_config.ign")
      . " -o /var/lib/libvirt/images/VIRT_TEST_VM_config.ign";
    script_retry($cmd, retry => 2, delay => 5, timeout => 60, die => 1);
    save_screenshot;
    assert_script_run("ls -latr /var/lib/libvirt/images/");
    record_info("Ignition file is successfully downloaded.");
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    # Let it empty now.
    # Need to let parent one called after yast team modifies the parent class to fit alp.
}

1;


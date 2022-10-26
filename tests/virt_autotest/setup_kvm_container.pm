# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This file handles the setup for kvm workload container for virtualization test.
# Maintainer: alice <xlai@suse.com>, qe-virt@suse.de

package setup_kvm_container;
use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use alp_workloads::kvm_workload_utils qw(set_kvm_container_image clean_and_resetup_kvm_container collect_kvm_container_setup_logs);

sub run {
    my $self = shift;

    if (get_var('KVM_WORKLOAD_IMAGE', '')) {
        set_kvm_container_image(get_var('KVM_WORKLOAD_IMAGE'));
    }

    clean_and_resetup_kvm_container;
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;

    collect_kvm_container_setup_logs;
}

1;


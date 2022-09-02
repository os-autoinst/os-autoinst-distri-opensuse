# SUSE's openQA tests
#
# Copyright @ SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: smoke test for cpuid on HPC
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use utils;

sub run ($self) {
    zypper_call('in cpuid');
    assert_script_run("cpuid > /tmp/output.txt 2>&1");
}

sub post_run_hook ($self) {
    upload_logs('/tmp/output.txt', failok => 1);
    $self->SUPER::post_run_hook();
}

sub post_fail_hook ($self) {
    upload_logs('/tmp/output.txt', failok => 1);
    $self->SUPER::post_fail_hook();
}

1;

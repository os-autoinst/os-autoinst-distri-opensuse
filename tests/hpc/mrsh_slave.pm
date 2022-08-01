# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HPC_Module: mrsh slave
#    This test is setting up a mrsh scenario according to the testcase
#    described in FATE
# Maintainer: Kernel QE <kernel-qa@suse.de>
# Tags: https://fate.suse.com/321722

use Mojo::Base 'hpcbase', -signatures;
use testapi;
use lockapi;
use utils;

sub run ($self) {
    # make sure that nobody has permissions for $serialdev to get openQA work properly
    assert_script_run("chmod 666 /dev/$serialdev");

    # install mrsh
    zypper_call('in mrsh mrsh-server');
    barrier_wait("MRSH_INSTALLATION_FINISHED");
    barrier_wait("MRSH_KEY_COPIED");

    # start munge
    $self->enable_and_start('munge');
    barrier_wait("MRSH_MUNGE_ENABLED");

    # Start the socket listener for mrlogind and mrsh
    $self->enable_and_start('mrlogind.socket mrshd.socket');
    barrier_wait("SLAVE_MRLOGIN_STARTED");
    barrier_wait("MRSH_MASTER_DONE");
}

sub test_flags ($self) {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook ($self) {
    $self->destroy_test_barriers();
    $self->select_serial_terminal;
    $self->upload_service_log('munge');
    $self->upload_service_log('mrshd');
    $self->upload_service_log('mrlogind');
}

1;

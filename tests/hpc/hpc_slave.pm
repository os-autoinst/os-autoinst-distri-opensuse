# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC Slave
#    This test is setting up an HPC slave node, so that various services
#    are ready to be used
# Maintainer: Sebastian Chlad <schlad@suse.de>

use base "hpcbase";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use version_utils 'is_sle';

sub run {
    my $self = shift;
    $self->prepare_user_and_group();
    zypper_call('in slurm-munge ganglia-gmond');
    # install slurm-node if sle15, not available yet for sle12
    zypper_call('in slurm-node') if is_sle '15+';

    barrier_wait("HPC_SETUPS_DONE");
    barrier_wait("HPC_MASTER_SERVICES_ENABLED");

    $self->enable_and_start("gmond");
    systemctl("is-active gmond");
    $self->enable_and_start("munge");
    systemctl("is-active munge");
    $self->enable_and_start("slurmd");
    systemctl("is-active slurmd");
    barrier_wait("HPC_SLAVE_SERVICES_ENABLED");
    barrier_wait("HPC_MASTER_RUN_TESTS");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->upload_service_log('slurmd');
    $self->upload_service_log('munge');
}

1;

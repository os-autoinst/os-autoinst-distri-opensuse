# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC_Module: slurm slave
#    This test is setting up a slurm slave and tests if the daemon can start
# Maintainer: soulofdestiny <mgriessmeier@suse.com>
# Tags: https://fate.suse.com/316379, https://progress.opensuse.org/issues/20308

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

    # Install slurm
    zypper_call('in slurm-munge');
    # install slurm-node if sle15, not available yet for sle12
    zypper_call('in slurm-node') if is_sle '15+';

    barrier_wait("SLURM_SETUP_DONE");
    barrier_wait("SLURM_MASTER_SERVICE_ENABLED");

    # enable and start munge
    $self->enable_and_start('munge');

    # enable and start slurmd
    $self->enable_and_start('slurmd');
    systemctl 'status slurmd';
    barrier_wait("SLURM_SLAVE_SERVICE_ENABLED");

    barrier_wait("SLURM_MASTER_RUN_TESTS");
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

# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation of munge package from HPC module and sanity check
# of this package
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>, soulofdestiny <mgriessmeier@suse.com>

use base "hpcbase";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;

sub run {
    my $self = shift;

    # Synchronize with master
    mutex_lock("MUNGE_MASTER_BARRIERS_CONFIGURED");
    mutex_unlock("MUNGE_MASTER_BARRIERS_CONFIGURED");

    # Stop firewall
    systemctl 'stop ' . $self->firewall;

    # install munge, wait for master and munge key
    zypper_call('in munge');
    barrier_wait('MUNGE_INSTALLATION_FINISHED');
    mutex_lock('MUNGE_KEY_COPIED');
    mutex_unlock('MUNGE_KEY_COPIED');

    # start and enable munge
    $self->enable_and_start('munge');
    barrier_wait("MUNGE_SERVICE_ENABLED");

    # wait for master to finish
    mutex_lock('MUNGE_DONE');
    mutex_unlock('MUNGE_DONE');
}

1;

# vim: set sw=4 et:


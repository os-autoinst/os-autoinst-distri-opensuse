# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
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
    select_console 'root-console';

    $self->setup_static_network(get_required_var('HPC_HOST_IP'));

    # stop firewall, so key can be copied
    assert_script_run "rcSuSEfirewall2 stop";

    # set proper hostname
    assert_script_run('hostnamectl set-hostname munge-slave');

    # install munge, wait for master and munge key
    zypper_call('in munge');
    barrier_wait('MUNGE_INSTALLATION_FINISHED');
    mutex_lock('MUNGE_KEY_COPIED');

    # start and enable munge
    $self->enable_and_start('munge');
    barrier_wait("MUNGE_SERVICE_ENABLED");

    # wait for master to finish
    mutex_lock('MUNGE_DONE');
}

1;

# vim: set sw=4 et:


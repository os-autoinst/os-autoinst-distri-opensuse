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

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use lockapi;
use utils;
use mm_network;
use mmapi;

sub run() {
    my $self    = shift;
    my $host_ip = get_required_var('HPC_HOST_IP');
    select_console 'root-console';

    # Setup static NETWORK
    configure_default_gateway;
    configure_static_ip($host_ip);
    configure_static_dns(get_host_resolv_conf());

    # check if gateway is reachable
    assert_script_run "ping -c 1 10.0.2.2 || journalctl -b --no-pager >/dev/$serialdev";

    # stop firewall, so key can be copied
    assert_script_run "rcSuSEfirewall2 stop";

    # set proper hostname
    assert_script_run('hostnamectl set-hostname munge-slave');

    # install munge, wait for master and munge key
    zypper_call('in munge');
    barrier_wait('INSTALLATION_FINISHED');
    mutex_lock('KEY_COPIED');

    # start enable service
    assert_script_run('systemctl enable munge.service');
    assert_script_run('systemctl start munge.service');
    barrier_wait("SERVICE_ENABLED");

    # wait for master to finish
    mutex_lock('MUNGE_DONE');
}

1;

# vim: set sw=4 et:


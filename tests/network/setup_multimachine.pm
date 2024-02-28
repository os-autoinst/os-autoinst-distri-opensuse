# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test preparing the static IP and hostname for simple multimachine tests
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use lockapi;
use mm_network 'setup_static_mm_network';
use utils qw(zypper_call permit_root_ssh set_hostname ping_size_check);
use Utils::Systemd qw(disable_and_stop_service systemctl check_unit_file);
use version_utils qw(is_sle is_opensuse);
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self) = @_;
    my $hostname = get_var('HOSTNAME');
    my $is_server = ($hostname =~ /server|master/);

    if ($is_server) {
        barrier_create 'MM_SETUP_DONE', 2;
        barrier_create 'MM_SETUP_PING_CHECK_DONE', 2;
        mutex_create 'barrier_setup_mm_done';
    }
    mutex_wait 'barrier_setup_mm_done';

    select_serial_terminal;
    # Do not use external DNS for our internal hostnames
    assert_script_run('echo "10.0.2.101 server master" >> /etc/hosts');
    assert_script_run('echo "10.0.2.102 client minion" >> /etc/hosts');

    # Configure static network, disable firewall
    disable_and_stop_service($self->firewall) if check_unit_file($self->firewall);
    disable_and_stop_service('apparmor', ignore_failure => 1);

    # Configure the internal network an  try it
    setup_static_mm_network($is_server ? '10.0.2.101/24' : '10.0.2.102/24');

    # Set the hostname to identify both minions
    set_hostname $hostname;

    # Make sure that PermitRootLogin is set to yes
    # This is needed only when the new SSH config directory exists
    # See: poo#93850
    permit_root_ssh();

    barrier_wait 'MM_SETUP_DONE';
    ping_size_check('server') unless $is_server;
    barrier_wait 'MM_SETUP_PING_CHECK_DONE';
}

1;


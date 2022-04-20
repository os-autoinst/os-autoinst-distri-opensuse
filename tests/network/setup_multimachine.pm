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
use utils qw(zypper_call permit_root_ssh set_hostname);
use Utils::Systemd qw(disable_and_stop_service systemctl check_unit_file);
use version_utils qw(is_sle is_opensuse);

sub run {
    my ($self) = @_;
    my $hostname = get_var('HOSTNAME');
    select_console 'root-console';

    # Do not use external DNS for our internal hostnames
    assert_script_run('echo "10.0.2.101 server master" >> /etc/hosts');
    assert_script_run('echo "10.0.2.102 client minion" >> /etc/hosts');

    # Configure static network, disable firewall
    disable_and_stop_service($self->firewall) if check_unit_file($self->firewall);
    disable_and_stop_service('apparmor', ignore_failure => 1);

    # Configure the internal network an  try it
    if ($hostname =~ /server|master/) {
        setup_static_mm_network('10.0.2.101/24');
    } else {
        setup_static_mm_network('10.0.2.102/24');
    }

    # Set the hostname to identify both minions
    set_hostname $hostname;

    # Make sure that PermitRootLogin is set to yes
    # This is needed only when the new SSH config directory exists
    # See: poo#93850
    permit_root_ssh();
}

1;


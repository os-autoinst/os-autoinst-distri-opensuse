# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test preparing the static IP and hostname for simple multimachine tests
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use lockapi;
use mm_network 'setup_static_mm_network';
use utils 'zypper_call';
use Utils::Systemd 'disable_and_stop_service';

sub run {
    my ($self) = @_;
    my $hostname = get_var('HOSTNAME');
    select_console 'root-console';

    # Do not use external DNS for our internal hostnames
    assert_script_run('echo "10.0.2.101 server master" >> /etc/hosts');
    assert_script_run('echo "10.0.2.102 client minion" >> /etc/hosts');

    # Configure static network, disable firewall
    disable_and_stop_service($self->firewall);

    # Configure the internal network an  try it
    if ($hostname =~ /server|master/) {
        setup_static_mm_network('10.0.2.101/24');
    }
    else {
        setup_static_mm_network('10.0.2.102/24');
    }

    # Set the hostname to identify both minions
    assert_script_run "hostnamectl set-hostname $hostname";
    assert_script_run "hostnamectl status|grep $hostname";
    assert_script_run "hostname|grep $hostname";
}

1;


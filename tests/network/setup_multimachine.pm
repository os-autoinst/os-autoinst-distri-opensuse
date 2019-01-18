# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
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
use y2x11test 'setup_static_mm_network';
use utils qw(zypper_call systemctl);

sub run {
    my ($self) = @_;
    my $hostname = get_var('HOSTNAME');
    select_console 'root-console';

    # Configure static network, disable firewall
    systemctl 'stop ' . $self->firewall;
    systemctl 'disable ' . $self->firewall;
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

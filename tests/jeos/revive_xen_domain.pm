# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Xen domain needs to be turned on and off
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'installbasetest';
use strict;
use testapi;
use utils;
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;

    power_action('reboot');
    # If we connect to 'sut' VNC display "too early" the VNC server won't be
    # ready we will be left with a blank screen.
    if (check_var('VIRSH_VMM_TYPE', 'hvm')) {
        $self->wait_boot;
    }
    elsif (check_var('VIRSH_VMM_TYPE', 'linux')) {
        my $timeout = 80;
        wait_serial('Welcome to SUSE Linux', $timeout) || die "System did not boot in $timeout seconds.";
    }
    select_console 'root-console';
}

sub test_flags {
    # On JeOS this is the time for first snapshot as system is deployed correctly.
    return {fatal => 1, milestone => 1};
}

1;

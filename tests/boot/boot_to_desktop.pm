# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot from existing image to desktop
# Maintainer: mitiao <mitiao@gmail.com>

use base 'opensusebasetest';
use strict;
use testapi;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    # We have tests that boot from HDD and wait for DVD boot menu's timeout, so
    # the timeout here must cover it. UEFI DVD adds some 60 seconds on top.
    my $timeout = get_var('UEFI') ? 140 : 80;
    if (check_var('VIRSH_VMM_TYPE', 'linux')) {
        wait_serial("Welcome to SUSE Linux", $timeout) || die "System did not boot in $timeout seconds.";
    }
    else {
        $self->wait_boot(bootloader_time => $timeout);
    }
    if (is_sle && !check_var('DESKTOP', 'textmode')) {
        x11_start_program('xterm');
        my $window_system = script_output('echo $XDG_SESSION_TYPE');
        script_run('exit', 0);
        record_info("$window_system", "Current window system is $window_system");
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};    # add milestone flag to save setup in lastgood VM snapshot
}

1;

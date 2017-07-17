# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: First boot and login into CASP
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils 'is_casp';

sub run {
    # On VMX images bootloader_uefi eats grub2 needle
    assert_screen 'grub2' unless is_casp('VMX');

    # Check ssh keys & ip information are displayed
    assert_screen 'linux-login-casp', 300;

    # Workers installed using autoyast have no password - bsc#1030876
    unless (get_var('AUTOYAST')) {
        # Workaround for bsc#1035968
        if (is_casp 'VMX') {
            my $tty2 = wait_screen_change(sub { send_key 'ctrl-alt-f2'; }, 1);
            unless ($tty2) {
                wait_screen_change(undef, 180);
                wait_still_screen;
                record_soft_failure 'bsc#1035968';
            }
        }
        select_console 'root-console';

        # Restart network to push hostname to dns
        if (is_casp('VMX') && get_var('STACK_ROLE')) {
            script_run "systemctl restart network", 60;
        }
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:

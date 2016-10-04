# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: libvirt domains need to be redefined after installation
# to restart properly
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "installbasetest";
use strict;
use testapi;
use utils;

sub run() {
    # Now we need to redefine libvirt domain; installation/redefine_svirt_domain
    # test should follow.
    if (is_jeos) {
        script_run 'poweroff', 0;
    }

    my $svirt = console('svirt');

    if (check_var('ARCH', 's390x') or get_var('NETBOOT')) {
        $svirt->change_domain_element(os => initrd => undef);
        $svirt->change_domain_element(os => kernel => undef);
        if (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')) {
            $svirt->change_domain_element(os => kernel => "/usr/lib/grub2/x86_64-xen/grub.xen");
        }
        $svirt->change_domain_element(os => cmdline => undef);
    }

    $svirt->change_domain_element(on_reboot => undef);

    if (!check_var('ARCH', 's390x')) {
        $svirt->change_domain_element(on_reboot => "restart");
    }

    $svirt->define_and_start;

    # On svirt backend we need to re-connect to 'sut' console which got
    # unusable after post-install shutdown. reset_consoles() makes
    # re-connect with credentials to 'sut' console possible.
    if (!check_var('ARCH', 's390x')) {
        reset_consoles;
        # If we connect to 'sut' VNC display "too early" the VNC server won't be
        # ready we will be left with a blank screen.
        if (check_var('VIRSH_VMM_FAMILY', 'vmware')) {
            sleep 2;
        }
        select_console 'sut';
    }

    if (is_jeos) {
        wait_boot;
        if (check_var('BACKEND', 'svirt') and !check_var('ARCH', 's390x')) {
            wait_idle;
        }
        select_console 'root-console';
    }
}

sub test_flags() {
    # on JeOS this is the time for first snapshot as system is deployed
    # and it's libvirt XML domain set to restart properly
    return {fatal => 1, milestone => is_jeos ? 1 : 0};
}

1;

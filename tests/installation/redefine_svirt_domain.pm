# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Split the svirt redefine to another test
# G-Maintainer: Stephan Kulow <coolo@suse.de>

use base "installbasetest";
use strict;
use testapi;

sub run() {

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
}

1;

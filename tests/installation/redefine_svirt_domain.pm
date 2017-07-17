# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: libvirt domains need to be redefined after installation
# to restart properly
# Maintainer: Matthias Griessmeier <mgriessmeier@suse.com>

use base 'installbasetest';
use strict;
use testapi;
use utils;

sub run {
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

    $svirt->define_and_start;
}

sub test_flags {
    return {fatal => 1};
}

1;

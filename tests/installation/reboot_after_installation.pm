# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare and trigger the reboot into the installed system
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use base 'y2logsstep';
use testapi;
use utils;

sub run {
    # on remote installations we can not try to switch to the installation
    # console but we never switched away, see
    # logs_from_installation_system.pm, so we should be safe to ignore this
    # call
    if (check_var('BACKEND', 'spvm')) {
        # this will only work for serial install
        select_console 'novalink-ssh', await_console => 0;
        assert_screen 'rebootnow';
    }
    else {
        select_console 'installation' unless get_var('REMOTE_CONTROLLER');
    }

    # svirt: Make sure we will boot from hard disk next time
    if (check_var('VIRSH_VMM_FAMILY', 'kvm') || check_var('VIRSH_VMM_FAMILY', 'xen')) {
        my $svirt = console('svirt');
        $svirt->change_domain_element(os => boot => {dev => 'hd'});
    }
    wait_screen_change {
        send_key 'alt-o';    # Reboot
    };

    power_action('reboot', observe => 1, keepconsole => 1);
}

1;

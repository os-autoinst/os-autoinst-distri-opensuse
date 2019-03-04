# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare and trigger the reboot into the installed system
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base 'y2logsstep';
use testapi;
use utils;
use power_action_utils 'power_action';
use Utils::Backends 'is_remote_backend';

sub run {
    select_console 'installation' unless get_var('REMOTE_CONTROLLER');

    # svirt: Make sure we will boot from hard disk next time
    if (check_var('VIRSH_VMM_FAMILY', 'kvm') || check_var('VIRSH_VMM_FAMILY', 'xen')) {
        my $svirt = console('svirt');
        $svirt->change_domain_element(os => boot => {dev => 'hd'});
    }
    # Reboot
    if (is_remote_backend) {
        # for now, on remote backends we need to trigger the reboot action
        # without waiting for a screen change as the remote console might
        # vanish immediately after the initial key press loosing the remote
        # socket end
        send_key 'alt-o';
    }
    else {
        my $count = 0;
        while (!wait_screen_change(sub { send_key 'alt-o' }, undef, similarity_level => 20)) {
            $count < 5 ? $count++ : die "Reboot process won't start";
        }
    }
    power_action('reboot', observe => 1, keepconsole => 1, first_reboot => 1);
}

1;

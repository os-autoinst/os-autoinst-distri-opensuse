# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package caasp;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use version_utils 'is_caasp';
use power_action_utils 'power_action';

our @EXPORT = qw(microos_reboot microos_login);

# Assert login prompt and login as root
sub microos_login {
    assert_screen 'linux-login-casp', 150;

    # Workers installed using autoyast have no password - bsc#1030876
    return if get_var('AUTOYAST');

    if (is_caasp 'VMX') {
        # FreeRDP is not sending 'Ctrl' as part of 'Ctrl-Alt-Fx', 'Alt-Fx' is fine though.
        my $key = check_var('VIRSH_VMM_FAMILY', 'hyperv') ? 'alt-f2' : 'ctrl-alt-f2';
        # First attempts to select tty2 are ignored - bsc#1035968
        send_key_until_needlematch 'tty2-selected', $key, 10, 30;
    }

    select_console 'root-console';

    # Don't match linux-login-casp twice
    assert_script_run 'clear';
}

# Process reboot with an option to trigger it
sub microos_reboot {
    my $trigger = shift // 0;
    power_action('reboot', observe => !$trigger, keepconsole => 1);

    # No grub bootloader on xen-pv
    # grub2 needle is unreliable (stalls during timeout) - poo#28648
    assert_screen [qw(grub2 linux-login-casp)], 150;
    send_key('ret') if match_has_tag('grub2');

    microos_login;
}

1;

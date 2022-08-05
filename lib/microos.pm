# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

package microos;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use version_utils qw(is_microos is_selfinstall);
use power_action_utils 'power_action';
use Utils::Architectures qw(is_aarch64);
use Utils::Backends qw(is_ipmi);

our @EXPORT = qw(microos_reboot microos_login);

# Assert login prompt and login as root
sub microos_login {
    my $login_timeout = (is_aarch64 || is_selfinstall) ? 300 : 150;
    assert_screen 'linux-login-microos', $login_timeout;

    if (is_microos 'VMX') {
        # FreeRDP is not sending 'Ctrl' as part of 'Ctrl-Alt-Fx', 'Alt-Fx' is fine though.
        my $key = check_var('VIRSH_VMM_FAMILY', 'hyperv') ? 'alt-f2' : 'ctrl-alt-f2';
        # First attempts to select tty2 are ignored - bsc#1035968
        send_key_until_needlematch 'tty2-selected', $key, 11, 30;
    }

    select_console 'root-console';

    # Don't match linux-login-microos twice
    assert_script_run 'clear';
}

# Process reboot with an option to trigger it
sub microos_reboot {
    my $trigger = shift // 0;
    power_action('reboot', observe => !$trigger, keepconsole => 1);

    # sol console has to be selected for ipmi backend before asserting grub needle.
    select_console 'sol', await_console => 0 if is_ipmi();
    # No grub bootloader on xen-pv
    # grub2 needle is unreliable (stalls during timeout) - poo#28648
    assert_screen 'grub2', 300;
    send_key('ret') unless get_var('KEEP_GRUB_TIMEOUT');
    microos_login;
}

1;

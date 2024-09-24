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
use utils qw(need_unlock_after_bootloader unlock_if_encrypted);
use version_utils qw(is_microos is_selfinstall is_bootloader_grub2 is_bootloader_sdboot);
use power_action_utils 'power_action';
use Utils::Architectures qw(is_aarch64);
use Utils::Backends qw(is_ipmi);

our @EXPORT = qw(microos_reboot handle_microos_reboot microos_login);

sub soft_reboot_consoles_fix {
    my (%args) = @_;
    $args{timeout} //= 600;
    $args{interval} //= 10;
    my $start_time = time;    # Track the start time
    my $succeeded = 0;

    while (!$succeeded && (time - $start_time < $args{timeout})) {
        $succeeded = 1 if check_screen('linux-login-microos', $args{interval});
        last if $succeeded;
        record_soft_failure "Fixaround for bsc#1231986";
        record_info("Jump to tty3");
        send_key check_var('VIRSH_VMM_FAMILY', 'hyperv') ? 'alt-f3' : 'ctrl-alt-f3';
        sleep 2;

        record_info("Jump to tty1");
        send_key check_var('VIRSH_VMM_FAMILY', 'hyperv') ? 'alt-f1' : 'ctrl-alt-f1';
        sleep 2;

        record_info("Jump to tty2");
        send_key check_var('VIRSH_VMM_FAMILY', 'hyperv') ? 'alt-f2' : 'ctrl-alt-f2';
        sleep 2;

    }
    die "linux-login-microos screen not found after timeout" unless $succeeded;
}

# Assert login prompt and login as root
sub microos_login {
    my (%args) = @_;
    $args{soft_reboot} //= 0;

    reset_consoles();

    my $login_timeout = (is_aarch64 || is_selfinstall) ? 300 : 150;
    soft_reboot_consoles_fix() if $args{soft_reboot};

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

sub handle_microos_reboot {
    # sol console has to be selected for ipmi backend before asserting grub needle.
    select_console 'sol', await_console => 0 if is_ipmi();
    # No grub bootloader on xen-pv
    # grub2 needle is unreliable (stalls during timeout) - poo#28648
    assert_screen 'grub2', 300 if is_bootloader_grub2;
    assert_screen 'systemd-boot', 300 if is_bootloader_sdboot;
    send_key('ret') unless get_var('KEEP_GRUB_TIMEOUT');
    unlock_if_encrypted if need_unlock_after_bootloader;
    microos_login;
}

# Process reboot with an option to trigger it
sub microos_reboot {
    my $trigger = shift // 0;
    power_action('reboot', observe => !$trigger, keepconsole => 1);
    handle_microos_reboot;
}

1;

# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Special handling to get to the desktop the first time after
#          the installation has been completed (either find the desktop after
#          auto-login or handle the login screen to reach the desktop)
# - Wait for login screen
# - Handle displaymanager
# - Handle login screen
# - Check if generic-desktop was reached
# Maintainer: Max Lin <mlin@suse.com>

use Mojo::Base 'bootbasetest';
use testapi;
use Utils::Architectures;
use x11utils qw(turn_off_plasma_tooltips update_x11_vt);

sub run {
    my $self = shift;
    # Workaround: on vmware or hyperv the 'ret' from grub_test is occasionally
    # lost across a VNC reconnect, leaving the SUT at the GRUB menu. Only these
    # backends reconnect the console, so the check is limited to them.
    if (check_var('VIRSH_VMM_FAMILY', 'vmware') || check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        console('sut')->disable_vnc_stalls;
        select_console('sut');
        if (check_screen('grub2', 5)) {
            record_info('bootloader still visible, resending ret');
            send_key 'ret';
        }
    }
    $self->handle_grub(bootloader_time => 300, in_grub => 0) if (!is_s390x && check_var('KEEP_GRUB_TIMEOUT', '0'));
    $self->wait_boot_past_bootloader;
    # This only works with generic-desktop. In the opensuse-welcome case,
    # the opensuse-welcome module will handle it instead.
    if (check_var('DESKTOP', 'kde') && match_has_tag('generic-desktop')) {
        turn_off_plasma_tooltips;
        update_x11_vt;
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

# 'generic-desktop' already checked in wait_boot_past_bootloader
sub post_run_hook { }

1;

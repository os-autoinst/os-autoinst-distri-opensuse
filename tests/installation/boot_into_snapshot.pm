# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot into root filesystem snapshot from boot menu
# uses grub menu to boot into the last RO snapshot made by snapper
# and verifies that `before_upgrade` and `after upgrade` are not identical.
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use warnings;
use testapi;
use base "opensusebasetest";
use bootloader_setup qw(stop_grub_timeout boot_into_snapshot);

sub run {
    my ($self) = @_;
    if (check_var('DESKTOP', 'gnome')) {
        assert_screen('generic-desktop', 200);
        select_console 'root-console';
        script_run("systemctl reboot", 0);
        # start from cdrom boot menu and it should boot from hard disk and select start bootloader for snapshot
        assert_screen('bootloader', 200);
        send_key 'ret';
        # boot into leap snapshot
        send_key_until_needlematch('start-bootloader-from-snapshot', 'down', 11, 5);
        send_key 'ret';
        send_key_until_needlematch('snapshot-before-upgrade', 'down', 41, 5);
        send_key 'ret';
        # Wait until the menu for that snapshot is shown
        assert_screen('snapshot-help');
        send_key_until_needlematch('opensuse-leap', 'down', 11, 5);
        send_key 'ret';
        save_screenshot;
        reset_consoles;
        assert_screen('generic-desktop', 200);
    }
    else {
        assert_screen('linux-login', 200);
        select_console 'root-console';
        script_run("systemctl reboot", 0);
        reset_consoles;
        stop_grub_timeout;
        boot_into_snapshot;
        assert_screen('linux-login', 200);
        select_console 'root-console';
        assert_script_run('touch /etc/NOWRITE;test ! -f /etc/NOWRITE');
        script_run("systemctl reboot", 0);
        reset_consoles;
        $self->wait_boot;
    }
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    $self->export_logs;
}

1;

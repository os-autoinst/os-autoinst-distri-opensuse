# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
        send_key_until_needlematch('start-bootloader-from-snapshot', 'down', 10, 5);
        send_key 'ret';
        send_key_until_needlematch('snapshot-before-upgrade', 'down', 40, 5);
        send_key 'ret';
        send_key_until_needlematch('opensuse-leap', 'down', 10, 5);
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


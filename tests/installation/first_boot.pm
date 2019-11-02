# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Special handling to get to the desktop the first time after
#          the installation has been completed (either find the desktop after
#          auto-login or handle the login screen to reach the desktop)
# - Wait for login screen
# - Select console type, x11 or ssh
# - Handle displaymanager
# - Handle login screen
# - Check if generic-desktop was reached
# - Disable wayland
# Maintainer: Max Lin <mlin@suse.com>

use strict;
use warnings;
use base 'bootbasetest';
use testapi;
use utils 'handle_emergency';
use version_utils qw(is_sle is_leap is_desktop_installed is_upgrade is_sles4sap);
use x11utils 'handle_login';
use main_common 'opensuse_welcome_applicable';

sub run {
    my ($self) = @_;
    # On IPMI, when selecting x11 console, we are connecting to the VNC server on the SUT.
    # select_console('x11'); also performs a login, so we should be at generic-desktop.
    my $gnome_ipmi = (check_var('BACKEND', 'ipmi') && check_var('DESKTOP', 'gnome'));
    if ($gnome_ipmi) {
        # first boot takes sometimes quite long time, ensure that it reaches login prompt
        $self->wait_boot(textmode => 1);
        select_console('x11');
    }
    my $boot_timeout = (check_var('VIRSH_VMM_FAMILY', 'hyperv') || check_var('BACKEND', 'ipmi')) ? 450 : 200;
    if (check_var('WORKER_CLASS', 'hornet')) {
        # hornet does not show the console output
        diag "waiting $boot_timeout seconds to let hornet boot and finish initial script";
        sleep $boot_timeout;
        reset_consoles;
        select_console 'root-ssh';
        return;
    }
    elsif ((get_var('DESKTOP', '') =~ /textmode|serverro/) || get_var('BOOT_TO_SNAPSHOT')) {
        assert_screen('linux-login', $boot_timeout) unless check_var('ARCH', 's390x');
        return;
    }
    # On SLES4SAP upgrade tests with desktop, only check for a DM screen with the SAP System
    # Administrator user listed but do not attempt to login
    if (get_var('HDDVERSION') and is_desktop_installed() and is_upgrade() and is_sles4sap()) {
        assert_screen 'displaymanager-sapadm', $boot_timeout;
        return;
    }
    # On IPMI, when selecting x11 console, we are already logged in.
    if ((get_var("NOAUTOLOGIN") || get_var("IMPORT_USER_DATA")) && !$gnome_ipmi) {
        assert_screen [qw(displaymanager emergency-shell emergency-mode)], $boot_timeout;
        handle_emergency if (match_has_tag('emergency-shell') or match_has_tag('emergency-mode'));
        handle_login;
    }

    my @tags = qw(generic-desktop);
    push(@tags, qw(opensuse-welcome)) if opensuse_welcome_applicable;
    # boo#1102563 - autologin fails on aarch64 with GNOME on current Tumbleweed
    if (!is_sle('<=15') && !is_leap('<=15.0') && check_var('ARCH', 'aarch64') && check_var('DESKTOP', 'gnome')) {
        push(@tags, 'displaymanager');
    }
    # GNOME and KDE get into screenlock after 5 minutes without activities.
    # using multiple check intervals here then we can get the wrong desktop
    # screenshot at least in case desktop screenshot changed, otherwise we get
    # the screenlock screenshot.
    my $timeout        = 600;
    my $check_interval = 30;
    while ($timeout > $check_interval) {
        my $ret = check_screen \@tags, $check_interval;
        last if $ret;
        $timeout -= $check_interval;
    }
    # the last check after previous intervals must be fatal
    assert_screen \@tags, $check_interval;
    if (match_has_tag('displaymanager')) {
        record_soft_failure 'boo#1102563 - GNOME autologin broken. Handle login and disable Wayland for login page to make it work next time';
        handle_login;
        assert_screen 'generic-desktop';
        # Force the login screen to use Xorg to get autologin working
        # (needed for additional tests using boot_to_desktop)
        x11_start_program('xterm');
        wait_still_screen;
        script_sudo('sed -i s/#WaylandEnable=false/WaylandEnable=false/ /etc/gdm/custom.conf');
        wait_screen_change { send_key 'alt-f4' };
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

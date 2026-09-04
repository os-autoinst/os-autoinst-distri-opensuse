# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: firewalld xrdp gnome-session-core
# Summary: Remote Login: Windows access SLES over RDP
# Maintainer: GraceWang <gwang@suse.com>
# Tags: tc#1610388

use Mojo::Base qw(x11test opensusebasetest);
use testapi;
use lockapi;
use mmapi;
use mm_tests;
use utils qw(systemctl);
use x11utils qw(handle_login turn_off_gnome_screensaver);
use version_utils qw(is_sle is_sles4sap is_tumbleweed is_transactional);
use package_utils qw(install_package);

sub run {
    my ($self) = @_;
    my $firewall = $self->firewall;

    # Open xterm session
    x11_start_program('xterm');
    turn_off_gnome_screensaver;
    become_root;

    # Setup static NETWORK
    if (is_tumbleweed) {
        $self->configure_static_ip_nm('10.0.2.17/24');
    }
    else {
        configure_static_network('10.0.2.17/24');
    }

    if (is_sles4sap) {
        # xrdp should already be installed in SLES4SAP
        assert_script_run 'rpm -q xrdp';

        # xrdp should already be started in SLES4SAP
        systemctl 'status xrdp';

        # A bug currently exists in SLES4SAP 15-SP1 with firewall not opened
        # during installation (bsc#1125529) - workaround it
        if (is_sle '=15-sp1') {
            record_soft_failure('workaround for bsc#1125529');
            # Add rules and reload firewall (firewalld is used in sle15+)
            assert_script_run 'firewall-cmd --zone=public --permanent --add-port=3389/tcp';
            systemctl "reload $firewall";
        }
    }
    else {
        # Install xrdp (transactional-aware: trup_apply lets us start the
        # service without a reboot on immutable images).
        install_package('xrdp', trup_apply => 1);

        # Add the firewall port for xrdp
        assert_script_run 'firewall-cmd --zone=public --permanent --add-port=3389/tcp';
        assert_script_run 'firewall-cmd --reload';

        # Start xrdp
        systemctl 'start xrdp';
    }

    # Terminate xterm session
    enter_cmd "exit";
    wait_screen_change { send_key 'alt-f4' };
    x11_start_program('gnome-session-quit --logout --force', valid => 0);

    # Notice xrdp server is ready for remote access
    mutex_create 'xrdp_server_ready';

    # Wait until xrdp client finishes remote access
    wait_for_children;

    # We have to click on the mouse before on ppc64le (bug?)
    mouse_click if get_var('OFW');
    send_key_until_needlematch 'displaymanager', 'esc';

    if (is_sles4sap || is_tumbleweed || is_transactional) {
        # We don't have to test the reconnection and reboot part in SLES4SAP, TW
        # or transactional/immutable images.
        handle_login;
    }

    else {
        # Click the bernhard user tile by coordinates instead of relying on
        # select_user_gnome — the SP5 needle set has no -user-notselected
        # sibling matching the small-avatar GDM state after RDP disconnect,
        # so select_user_gnome times out. A single click activates the tile
        # in both pre-selected (SP4) and not-selected (SP5) GDM variants.
        mouse_set(450, 370);
        mouse_click;
        assert_screen 'displaymanager-password-prompt';
        type_password;
        wait_still_screen 3;
        send_key "ret";
        assert_screen "multiple-logins-notsupport";

        # Force restart on gdm to check if the active session number is correct
        assert_and_click "status-bar";
        assert_and_click "power-button";
        if (is_sle('>=15-SP4')) {
            assert_and_click('reboot-click-restart');
        }

        else {
            assert_screen([qw(other-users-logged-in-1user other-users-logged-in-2users)]);
            if (match_has_tag('other-users-logged-in-2users')) {
                record_soft_failure 'bsc#1116281 GDM didnt behave correctly when the error message Multiple logins are not supported. is triggered';
            }
        }

        assert_and_click "force-restart";
        type_password;
        send_key "ret";

        $self->wait_boot;
    }
}

1;

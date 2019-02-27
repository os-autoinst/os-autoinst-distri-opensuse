# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Remote Login: Windows access SLES over RDP
# Maintainer: GraceWang <gwang@suse.com>
# Tags: tc#1610388

use strict;
use warnings;
use base 'x11test';
use testapi;
use lockapi;
use mmapi;
use mm_tests;
use base 'opensusebasetest';
use utils qw(systemctl zypper_call);
use x11utils qw(handle_login turn_off_gnome_screensaver);
use version_utils qw(is_sle is_sles4sap);

sub run {
    my ($self) = @_;
    my $firewall = $self->firewall;

    # Open xterm session
    x11_start_program('xterm');
    turn_off_gnome_screensaver;
    become_root;

    # Setup static NETWORK
    configure_static_network('10.0.2.17/24');

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
        # Install xrdp
        zypper_call('in xrdp');

        # Add the firewall port for xrdp
        assert_script_run 'firewall-cmd --zone=public --permanent --add-port=3389/tcp';
        assert_script_run 'firewall-cmd --reload';

        # Start xrdp
        systemctl 'start xrdp';
    }

    # Terminate xterm session
    type_string "exit\n";
    wait_screen_change { send_key 'alt-f4' };
    x11_start_program('gnome-session-quit --logout --force', valid => 0);

    # Notice xrdp server is ready for remote access
    mutex_create 'xrdp_server_ready';

    # Wait until xrdp client finishes remote access
    wait_for_children;

    if (is_sles4sap) {
        # We don't have to test the reconnection and reboot part in SLES4SAP
        handle_login;
    }
    else {
        send_key_until_needlematch 'displaymanager', 'esc';
        send_key 'ret';
        assert_screen "displaymanager-password-prompt";
        type_password;
        wait_still_screen 3;
        send_key "ret";
        assert_screen "multiple-logins-notsupport";

        # Force restart on gdm to check if the active session number is correct
        assert_and_click "status-bar";
        assert_and_click "power-button";
        assert_screen([qw(other-users-logged-in-1user other-users-logged-in-2users)]);

        if (match_has_tag('other-users-logged-in-2users')) {
            record_soft_failure 'bsc#1116281 GDM didnt behave correctly when the error message Multiple logins are not supported. is triggered';
        }
        assert_and_click "force-restart";
        type_password;
        send_key "ret";

        $self->wait_boot;
    }
}

1;

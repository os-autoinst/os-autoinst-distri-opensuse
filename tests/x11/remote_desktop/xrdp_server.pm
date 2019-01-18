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
use utils 'zypper_call';
use x11utils 'turn_off_gnome_screensaver';

sub run {
    my ($self) = @_;

    # Setup static NETWORK
    x11_start_program('xterm');
    turn_off_gnome_screensaver;
    become_root;
    configure_static_network('10.0.2.17/24');

    # Install xrdp
    zypper_call('in xrdp');

    # Add the firewall port for xrdp
    x11_start_program('xterm');
    become_root;
    assert_script_run 'firewall-cmd --zone=public --permanent --add-port=3389/tcp';
    assert_script_run 'firewall-cmd --reload';
    type_string "exit\n";
    wait_screen_change { send_key 'alt-f4' };

    # Start xrdp
    assert_script_run "systemctl start xrdp";
    type_string "exit\n";
    wait_screen_change { send_key 'alt-f4' };
    x11_start_program('gnome-session-quit --logout --force', valid => 0);

    # Notice xrdp server is ready for remote access
    mutex_create 'xrdp_server_ready';

    # Wait until xrdp client finishes remote access
    wait_for_children;

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
1;

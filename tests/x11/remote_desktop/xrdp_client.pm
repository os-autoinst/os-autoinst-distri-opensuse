# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: remmina
# Summary: Remote Login: SLED access Windows over RDP
# Maintainer: GraceWang <gwang@suse.com>
# Tags: tc#1610392

use strict;
use warnings;
use base 'x11test';
use testapi;
use version_utils ':VERSION';
use lockapi;
use mmapi;
use mm_tests;

sub run {
    my $self = shift;
    # Setup static NETWORK
    $self->configure_static_ip_nm('10.0.2.17/24');

    mutex_lock 'win_server_ready';

    ensure_installed('remmina');

    # Disable Remmina news before launch Remmina
    x11_start_program('xterm');
    my $pref_dir = '~/.config/remmina';
    assert_script_run "mkdir -p $pref_dir";
    assert_script_run 'echo -e "[remmina_news]\\nperiodic_rmnews_last_get=$(date +%s)" >> ' . $pref_dir . '/remmina.pref';
    # Using H.264 is the default option, but we don't support that out of the box, so choose RemoteFX instead.
    # (Disabling this using the UI is cumbersome, tab handling is broken, doesn't scroll)
    assert_script_run 'echo -e "[remmina]\\ncolordepth=0" >> ' . $pref_dir . '/remmina.pref';
    enter_cmd "exit";

    # Start Remmina and login the remote server
    x11_start_program('remmina', valid => 0);
    check_screen 'enter-pwd-2-unlock-keyring';
    if (match_has_tag 'enter-pwd-2-unlock-keyring') {
        type_password;
        assert_and_click "unlock-keyring";
    }

    assert_screen 'remmina-launched';
    type_string '10.0.2.18';
    send_key 'ret';
    assert_and_click 'accept-certificate-yes';
    assert_screen 'enter_auth_credentials';
    # We can not use the variable $realname here
    # Since the windows username limit is 20 characters
    # The username in windows is different from the $realname
    type_string "Bernhard M. Wiedeman";
    send_key "tab";
    type_password;
    assert_and_click 'auth_credentials-ok';

    wait_still_screen 3;
    assert_screen [qw(connection-failed windows-desktop-on-remmina)], 180;

    if (match_has_tag 'connection-failed') {
        record_soft_failure 'bsc#1117402 - Remmina is not able to connect to the windows server';
        send_key "alt-f4";
    }
    else {
        assert_and_click "close-remote-connection";
    }

    # close remmina and clean the preferences file
    send_key "alt-f4";
    x11_start_program('rm ~/.config/remmina/remmina.pref', valid => 0);
}
1;

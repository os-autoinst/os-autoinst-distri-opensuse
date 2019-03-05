# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Remote Login: SLED access Windows over RDP
# Maintainer: GraceWang <gwang@suse.com>
# Tags: tc#1610392

use strict;
use warnings;
use base 'x11test';
use testapi;
use lockapi;
use mmapi;
use mm_tests;

sub run {
    my $self = shift;

    # Setup static NETWORK
    $self->configure_static_ip_nm('10.0.2.17/24');

    mutex_lock 'win_server_ready';

    # Start Remmina and login the remote server
    x11_start_program('remmina', target_match => 'remmina-launched');
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
    assert_screen [qw(connection-failed windows-desktop-on-remmina)];
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

# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;
use utils;

# log out, check lightdm-gtk-greeter and log in again

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    x11_start_program("xfce4-session-logout");
    send_key "alt-l";
    assert_screen_with_soft_timeout('test-xfce_lightdm_logout_login-1', soft_timeout => 13);
    mouse_hide();
    type_password;
    send_key "ret";
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:

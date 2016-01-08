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
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("xdg-su -c '/sbin/yast2 users'");
    if ($password) { type_password; send_key "ret", 1; }
    assert_screen 'test-yast2_users-1', 60;
    send_key "alt-o";    # OK => Exit
}

1;
# vim: set sw=4 et:

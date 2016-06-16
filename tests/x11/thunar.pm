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

# test thunar and open the root directory

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    x11_start_program("thunar");
    sleep 10;
    send_key "shift-tab";
    send_key "home";
    send_key "down";
    assert_screen_with_soft_timeout('test-thunar-1', soft_timeout => 3);
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:

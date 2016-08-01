# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11regressiontest";
use strict;
use testapi;

# install tomboy

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    mouse_hide();
    sleep 60;
    wait_idle;
    ensure_installed("tomboy");
    send_key "ret";
    sleep 90;
    send_key "esc";
    sleep 5;
    wait_idle;

    #save_screenshot;
}

1;
# vim: set sw=4 et:

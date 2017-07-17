# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Gedit: Start and exit
# Maintainer: mitiao <mitiao@gmail.com>
# Tags: tc#1436122

use base "x11regressiontest";
use strict;
use testapi;

sub run {
    x11_start_program("gedit");
    assert_screen 'gedit-launched', 3;
    assert_and_click 'gedit-x-button';

    x11_start_program("gedit");
    assert_screen 'gedit-launched', 3;
    send_key "ctrl-q";
}

1;
# vim: set sw=4 et:

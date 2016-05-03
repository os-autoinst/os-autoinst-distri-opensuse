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

sub run() {
    my $self = shift;
    x11_start_program("oowriter");
    assert_screen 'test-ooffice-1', 30;
    # clicking the writing area to make sure the cursor addressed there
    assert_and_click 'ooffice-writing-area', 'left', 10;
    wait_idle 10;
    type_string "Hello World!";
    assert_screen 'test-ooffice-2', 5;
    send_key "alt-f4";
    assert_screen "ooffice-save-prompt", 8;
    assert_and_click 'dont-save-libreoffice-btn';    # _Don't save
}

1;
# vim: set sw=4 et:

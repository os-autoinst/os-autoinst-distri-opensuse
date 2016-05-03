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
    x11_start_program("oocalc", 6, {valid => 1});
    sleep 2;
    wait_still_screen;    # extra wait because oo sometimes appears to be idle during start
    assert_screen 'test-oocalc-1', 3;
    assert_and_click 'input-area-oocalc', 'left', 10;
    wait_idle 10;
    type_string "Hello World!\n";
    sleep 2;
    assert_screen 'test-oocalc-2', 3;
    send_key "alt-f4";
    sleep 2;
    assert_screen 'test-oocalc-3', 3;
    assert_and_click 'dont-save-libreoffice-btn';    # _Don't save
}

sub ocr_checklist() {
    [

        #                {screenshot=>2, x=>104, y=>201, xs=>380, ys=>150, pattern=>"H ?ello", result=>"OK"}
    ];
}

1;
# vim: set sw=4 et:

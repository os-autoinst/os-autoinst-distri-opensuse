# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: libreoffice-calc
# Summary: Startup, basic input and shutdown of oocalc
# - Launch oocalc
# - Type "Hello World!"
# - Close oocalc
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = shift;

    $self->libreoffice_start_program('oocalc');
    wait_still_screen;    # extra wait because oo sometimes appears to be idle during start
    wait_screen_change { assert_and_click('input-area-oocalc', timeout => 10) };
    enter_cmd "Hello World!";
    assert_screen 'test-oocalc-2';
    send_key "alt-f4";
    assert_screen 'test-oocalc-3';
    assert_and_click 'dont-save-libreoffice-btn';    # _Don't save
}

sub ocr_checklist {
    [

        #                {screenshot=>2, x=>104, y=>201, xs=>380, ys=>150, pattern=>"H ?ello", result=>"OK"}
    ];
}

1;

# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "basetest";
use strict;
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("banshee");
    assert_screen 'test-banshee-1', 3;
    send_key "ctrl-q";    # really quit (alt-f4 just backgrounds)
    send_key "alt-f4";
    wait_idle;
}

sub ocr_checklist() {
    [

        {screenshot => 1, x => 8, y => 150, xs => 140, ys => 380, pattern => "(?si:Vide.s.*Fav.rites.*Unwatched)", result => "OK"}];
}

1;

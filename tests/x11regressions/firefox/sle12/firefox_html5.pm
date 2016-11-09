# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1479221: Firefox: HTML5 Video
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    my ($self) = @_;
    $self->start_firefox;

    send_key "esc";
    send_key "alt-d";
    type_string "youtube.com/html5\n";

    assert_screen('firefox-html5-youtube', 90);
    send_key "pgdn";
    send_key "up";
    sleep 1;
    assert_screen('firefox-html5-support', 60);

    sleep 1;
    send_key "esc";
    send_key "alt-d";
    type_string "youtube.com/watch?v=Z4j5rJQMdOU\n";
    assert_screen('firefox-flashplayer-video_loaded', 90);

    # Exit
    $self->exit_firefox;
}
1;
# vim: set sw=4 et:

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

sub run() {
    my $self = shift;
    ensure_installed("amarok");
    x11_start_program("amarok", 6, {valid => 1});
    assert_screen_with_soft_timeout('test-amarok-1', soft_timeout => 3);
    send_key "alt-y";    # use music path as collection folder
                         # a workaround for librivox authentication popup window.
                         # and don't put this after opening oga file, per video
                         # the window pop-up meanwhile x11_start_progran typeing,
                         # and 40 sec to wait that window pop-up should enough
    if (check_screen "librivox-authentication", 40) {
        send_key "alt-c";    # cancel librivox certificate
    }
    assert_screen_with_soft_timeout('test-amarok-2', soft_timeout => 3);
    # do not playing audio file as we have not testdata if NICEVIDEO
    if (!get_var("NICEVIDEO")) {
        start_audiocapture;
        x11_start_program("amarok -l ~/data/1d5d9dD.oga");
        assert_screen_with_soft_timeout('test-amarok-3', soft_timeout => 10);
        assert_recorded_sound('DTMF-159D');
    }
    send_key "ctrl-q";       # really quit (alt-f4 just backgrounds)
}

1;
# vim: set sw=4 et:

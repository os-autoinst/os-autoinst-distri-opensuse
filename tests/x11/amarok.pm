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
    ensure_installed("amarok");
    x11_start_program("amarok", 6, {valid => 1});
    assert_screen 'test-amarok-1', 3;
    send_key "alt-y";    # use music path as collection folder
                         # a workaround for librivox authentication popup window.
                         # and don't put this after opening oga file, per video
                         # the window pop-up meanwhile x11_start_progran typeing,
                         # and 40 sec to wait that window pop-up should enough
    check_act_and_assert_screen('test-amarok-2', librivox-authentication => sub {
        send_key "alt-c";    # cancel librivox certificate
    });
    # do not playing audio file as we have not testdata if NICEVIDEO
    if (!get_var("NICEVIDEO")) {
        start_audiocapture;
        x11_start_program("amarok -l ~/data/1d5d9dD.oga");
        assert_screen 'test-amarok-3', 10;
        assert_recorded_sound('DTMF-159D');
    }
    send_key "ctrl-q";       # really quit (alt-f4 just backgrounds)
}

1;
# vim: set sw=4 et:

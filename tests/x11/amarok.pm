# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic amarok test with sound check
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    ensure_installed("amarok");
    x11_start_program('amarok');
    send_key "alt-y";    # use music path as collection folder
                         # a workaround for librivox authentication popup window.
                         # and don't put this after opening oga file, per video
                         # the window pop-up meanwhile x11_start_progran typeing,
                         # and 40 sec to wait that window pop-up should enough
    assert_screen([qw(librivox-authentication test-amarok-2)]);
    if (match_has_tag('librivox-authentication')) {
        send_key "alt-c";    # cancel librivox certificate
        assert_screen 'test-amarok-2';
    }
    # do not playing audio file as we have not testdata if NICEVIDEO
    if (!get_var("NICEVIDEO")) {
        start_audiocapture;
        x11_start_program('amarok -l ~/data/1d5d9dD.oga', target_match => 'test-amarok-3');
        assert_recorded_sound('DTMF-159D');
    }
    send_key "ctrl-q";       # really quit (alt-f4 just backgrounds)
}

1;

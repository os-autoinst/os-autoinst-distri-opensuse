# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test audio playback in firefox
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use testapi;

sub run {
    start_audiocapture;
    x11_start_program("firefox " . autoinst_url . "/data/1d5d9dD.oga");
    assert_screen 'test-firefox_audio-1', 35;
    sleep 1;    # at least a second of silence
    assert_recorded_sound('DTMF-159D');
    send_key "alt-f4";
    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}

1;
# vim: set sw=4 et:

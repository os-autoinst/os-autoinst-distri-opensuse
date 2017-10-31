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
use base "x11regressiontest";
use strict;
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox();
    send_key "ctrl-l";
    type_string(autoinst_url . "/data/1d5d9dD.oga");
    if (check_screen('firefox_audio_mistyped_url')) {
        record_soft_failure('poo25654 - URL mistyped; retrying');
        send_key "ctrl-l";
        type_string(autoinst_url . "/data/1d5d9dD.oga");
    }
    send_key "ret";
    start_audiocapture;
    assert_screen 'test-firefox_audio-1', 35;
    sleep 1;    # at least a second of silence
    assert_recorded_sound('DTMF-159D');
    send_key "alt-f4";
    $self->exit_firefox();
}

1;
# vim: set sw=4 et:

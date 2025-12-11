# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: amarok
# Summary: Basic amarok test with sound check
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use testapi;

sub run {
    select_console 'user-console';
    assert_script_run('curl -f ' . autoinst_url . '/data/1d5d9dD.oga -o /tmp/1d5d9dD.oga');
    select_console 'x11';
    ensure_installed("amarok");
    x11_start_program('amarok');
    assert_screen([qw(test-amarok-new-1 test-amarok-1)]);
    # use music path as collection folder
    # a workaround for librivox authentication popup window.
    # and don't put this after opening oga file, per video
    # the window pop-up meanwhile x11_start_progran typeing,
    # and 40 sec to wait that window pop-up should enough
    send_key(match_has_tag('test-amarok-new-1') ? 'alt-u' : 'alt-y');
    assert_screen([qw(librivox-authentication test-amarok-2)]);
    if (match_has_tag('librivox-authentication')) {
        send_key "alt-c";    # cancel librivox certificate
        assert_screen 'test-amarok-2';
    }
    # do not playing audio file as we have not testdata if NICEVIDEO
    if (!get_var("NICEVIDEO")) {
        start_audiocapture;
        x11_start_program('amarok -l /tmp/1d5d9dD.oga', target_match => 'test-amarok-3');
        assert_recorded_sound('DTMF-159D');
    }
    send_key "ctrl-q";    # really quit (alt-f4 just backgrounds)
}

1;

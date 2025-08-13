# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Test audio playback in firefox
#  Depending on if firefox has been started in before firefox might behave
#  different but should always show the play controls which the test is
#  looking for.
# - Start audio capture subsystem
# - Start firefox opening file "1d5d9dD.oga" from datadir
# - Check recorded sound
# - Exit firefox
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    select_console 'x11';
    start_audiocapture;
    x11_start_program('firefox ' . data_url('1d5d9dD.oga'), target_match => [qw(command-not-found test-firefox_audio-1 test-firefox_audio-notplayed)], match_timeout => 90);
    #  re-try for typing issue, see https://progress.opensuse.org/issues/54401
    if (match_has_tag 'command-not-found') {
        for my $retry (0 .. 2) {
            send_key 'esc';
            x11_start_program('firefox ' . data_url('1d5d9dD.oga'), target_match => 'test-firefox_audio-1', match_timeout => 90);
            last if (match_has_tag 'test-firefox_audio-1');
        }
    }
    if (match_has_tag 'test-firefox_audio-notplayed') {
        record_info('poo#186585', 'Play the audio file manually');
        send_key_until_needlematch('test-firefox_audio-1', 'spc', 3, 3);
    }
    sleep 1;    # at least a second of silence

    unless (check_recorded_sound 'DTMF-159D') {
        record_info("bsc#1048271", "WONTFIX - Tones are sporadically played with lower frequencies");
    }
    send_key 'alt-f4';
    assert_screen([qw(firefox-save-and-quit generic-desktop)]);
    send_key 'ret' if match_has_tag 'firefox-save-and-quit';
}

1;

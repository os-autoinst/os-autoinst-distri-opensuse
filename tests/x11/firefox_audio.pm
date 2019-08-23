# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test audio playback in firefox
#  Depending on if firefox has been started in before firefox might behave
#  different but should always show the play controls which the test is
#  looking for.
# - Start audio capture subsystem
# - Start firefox opening file "1d5d9dD.oga" from datadir
# - Check recorded sound
# - Exit firefox
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    start_audiocapture;
    x11_start_program('firefox ' . data_url('1d5d9dD.oga'), target_match => [qw(command-not-found test-firefox_audio-1)], match_timeout => 90);
    #  re-try for typing issue, see https://progress.opensuse.org/issues/54401
    if (match_has_tag 'command-not-found') {
        for my $retry (0 .. 2) {
            send_key 'esc';
            x11_start_program('firefox ' . data_url('1d5d9dD.oga'), target_match => 'test-firefox_audio-1', match_timeout => 90);
            last if (match_has_tag 'test-firefox_audio-1');
        }
    }
    sleep 1;    # at least a second of silence

    # firefox_audio is unstable due to bsc#1048271, we don't want to invest
    # time in rerunning it, if it fails, so instead of assert, simply soft-fail
    unless (check_recorded_sound 'DTMF-159D') {
        record_soft_failure 'bsc#1048271';
    }
    send_key 'alt-f4';
    assert_screen([qw(firefox-save-and-quit generic-desktop)]);
    send_key 'ret' if match_has_tag 'firefox-save-and-quit';
}

1;

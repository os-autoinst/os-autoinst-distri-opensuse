# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Using soundstretch to change original track and check the result, changing:
# - rate
# - tempo and pitch
# - bmp
# Maintainer: Katerina Lorenzova <klorenzova@suse.cz>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call "in soundtouch";
    zypper_call "in alsa-utils";

    select_console 'user-console';
    assert_script_run 'mkdir soundtouch';
    assert_script_run 'set_default_volume -f';

    assert_script_run 'soundstretch data/1d5d9dD.wav soundtouch/1d5d9dD_rate.wav -rate=+35';
    assert_script_run 'soundstretch data/1d5d9dD.wav soundtouch/1d5d9dD_tempo-and-pitch.wav -tempo=-60 -pitch=-6';
    #soundstrech is not able to detect bpm on 1d5d9dD.wav, using bar.wav instead
    assert_script_run 'soundstretch data/bar.wav soundtouch/bar_bpm.wav -bpm=60';

    start_audiocapture;
    assert_script_run 'aplay soundtouch/1d5d9dD_rate.wav soundtouch/1d5d9dD_tempo-and-pitch.wav soundtouch/bar_bpm.wav';
    assert_recorded_sound 'soundtouch';
    assert_script_run 'rm -rf soundtouch';
}
1;

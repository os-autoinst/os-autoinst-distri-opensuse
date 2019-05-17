# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test basic functionality of wavpack audio compression format.
# Maintainer: Ednilson Miura <emiura@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';
use registration 'add_suseconnect_product';

sub run {
    # setup
    select_console 'root-console';
    add_suseconnect_product('sle-module-desktop-applications') if is_sle("15-sp1+");
    zypper_call 'in alsa alsa-utils wavpack';
    assert_script_run("cp /usr/share/sounds/alsa/Noise.wav .");
    assert_script_run("cp /usr/share/sounds/alsa/test.wav .");
    assert_script_run("cp /usr/share/sounds/alsa/Side_Left.wav .");

    # test wavpack functions
    assert_script_run("wavpack Noise.wav -o Noise.wv 2>&1 | grep \"created Noise.wv\"");
    assert_script_run("wavpack -f test.wav 2>&1 | grep \"created test.wv\"");
    assert_script_run("wavpack -hh test.wav -o test1.wv 2>&1 | grep \"created test1.wv\"");
    assert_script_run("ls Side_Left.wav");
    assert_script_run("wavpack -d Side_Left.wav 2>&1 | grep -Pzo \"deleted source file Side_Left.wav(.|\\n)*created Side_Left.wv\"");

    # test wavunpack functions
    assert_script_run("wvunpack Noise.wv -o Noise2.wav 2>&1 | grep  \"restored Noise2.wav\"");
    assert_script_run("aplay Noise2.wav 2>&1 | grep \"Signed 16 bit Little Endian, Rate 48000 Hz, Mono\"");
    assert_script_run("wvunpack -v Noise.wv 2>&1 | grep  \"verified Noise.wv\"");

    # test wavgain functions
    assert_script_run("wvgain -d Noise.wv 2>&1 | grep -Pzo \"replaygain_track_gain = \\+11.06 dB(.|\\n)*replaygain_track_peak = 0.126251\"");
    assert_script_run("wvgain -s Noise.wv 2>&1 | grep \"no ReplayGain values found\"");
    assert_script_run("wvgain Noise.wv 2>&1 | grep -Pzo \"replaygain_track_gain = \\+11.06 dB(.|\\n)*replaygain_track_peak = 0.126251(.|\\n)*2 ReplayGain values appended\"");
    assert_script_run("wvgain -s Noise.wv 2>&1 | grep -Pzo \"replaygain_track_gain = \\+11.06 dB(.|\\n)*replaygain_track_peak = 0.126251\"");
}

1;

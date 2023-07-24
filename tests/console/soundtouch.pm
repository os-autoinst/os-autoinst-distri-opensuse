# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: soundtouch alsa-utils
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
use registration qw(cleanup_registration register_product add_suseconnect_product get_addon_fullname remove_suseconnect_product);
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    # development module needed for dependencies, released products are tested with sdk module
    if (is_sle() && !main_common::is_updates_tests()) {
        cleanup_registration;
        register_product;
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product(get_addon_fullname('sdk'));
    }
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
    # aplay is  unstable due to bsc#1048271, we don't want to invest
    # time in rerunning it, if it fails, so instead of assert, simply soft-fail
    record_soft_failure 'bsc#1048271' unless check_recorded_sound 'soundtouch';
    assert_script_run 'rm -rf soundtouch';
    # unregister SDK
    if (is_sle() && !main_common::is_updates_tests()) {
        select_console 'root-console';
        remove_suseconnect_product(get_addon_fullname('sdk'));
    }
}
1;

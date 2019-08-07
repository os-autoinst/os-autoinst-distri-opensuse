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
use registration qw(cleanup_registration register_product add_suseconnect_product get_addon_fullname remove_suseconnect_product);
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    # development module needed for dependencies, released products are tested with sdk module
    if (is_sle) {
        if (get_var('BETA')) {
            my $sdk_repo = is_sle('15+') ? get_var('REPO_SLE_MODULE_DEVELOPMENT_TOOLS') : get_var('REPO_SLE_SDK');
            zypper_ar 'http://' . get_var('OPENQA_URL') . "/assets/repo/$sdk_repo", name => 'SDK';
        }
        # maintenance updates are registered with sdk module
        elsif (get_var('FLAVOR') !~ /Updates|Incidents/) {
            cleanup_registration;
            register_product;
            add_suseconnect_product('sle-module-desktop-applications') if is_sle('15+');
            add_suseconnect_product(get_addon_fullname('sdk'));
        }
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
    assert_recorded_sound 'soundtouch';
    assert_script_run 'rm -rf soundtouch';
    # unregister SDK
    if (is_sle) {
        select_console 'root-console';
        if (get_var('BETA')) {
            zypper_call "rr SDK";
        }
        elsif (get_var('FLAVOR') !~ /Updates|Incidents/) {
            remove_suseconnect_product(get_addon_fullname('sdk'));
        }
    }
}
1;

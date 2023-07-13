# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-country
# Summary: yast2_lang.pm checks basic settings of language
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'x11';
    y2_module_guitest::launch_yast2_module_x11('language', match_timeout => 240);

    # check language details and change detailed locale setting
    assert_and_click 'yast2-lang_details';
    assert_screen 'yast2-lang_detailed-locale-setting';
    send_key 'alt-d';
    send_key_until_needlematch 'yast2-lang_detailed-locale-setting_changed', 'up';
    send_key 'alt-o';

    # change adapt time zone to German
    assert_and_click 'yast2-lang_adapt-timezone';
    assert_and_click 'yast2-lang_secondary-language';
    assert_screen 'yast2-lang_settings_done';

    # Problem here is that sometimes installation takes longer than 10 minutes
    # And then screen saver is activated, so add this step to wake
    my $timeout = 0;
    until (check_screen('generic-desktop', 30) || ++$timeout > 10) {
        # Now it will install required language packages and exit
        # Put in the loop, because sometimes button is not pressed
        wait_screen_change { send_key 'alt-o'; };
        sleep 60;
        send_key 'ctrl';
    }
}

# override for base class to allow a longer timeout for package installation
# before returning to desktop
sub post_run_hook {
    assert_screen 'generic-desktop', 600;
}


1;

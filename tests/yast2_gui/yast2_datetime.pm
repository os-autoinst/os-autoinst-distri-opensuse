# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-country chrony
# Summary: YaST2 UI test yast2_datetime checks minium settings for clock and time zone
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
    y2_module_guitest::launch_yast2_module_x11('timezone', target_match => [qw(yast2-datetime-ui yast2-datetime_ntp-conf require_install_chrony)], match_timeout => 90);
    if (match_has_tag 'yast2-datetime_ntp-conf') {
        send_key 'alt-d';
        send_key 'alt-o';
    }
    elsif (match_has_tag 'require_install_chrony') {
        record_soft_failure 'bsc#1072351';
        send_key 'alt-i';
    }
    assert_screen 'yast2-timezone-ui', 60;

    # check map and location, other settings can be added later
    assert_and_click 'yast2-datetime_map';
    assert_and_click 'yast2-datetime_location';
    assert_screen 'yast2-timezone-ui', 60;

    # OK => Exit
    send_key "alt-o";
}

1;

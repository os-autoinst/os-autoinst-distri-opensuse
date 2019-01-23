# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: YaST2 UI test yast2_datetime checks minium settings for clock and time zone
#    Make sure those yast2 modules can opened properly. We can add more
#    feature test against each module later, it is ensure it will not crashed
#    while launching atm.
# Maintainer: Zaoliang Luo <zluo@suse.com>

use base "y2x11test";
use strict;
use testapi;

sub run {
    my $self = shift;
    select_console 'x11';
    $self->launch_yast2_module_x11('timezone', target_match => [qw(yast2-datetime-ui yast2-datetime_ntp-conf require_install_chrony)], match_timeout => 90);
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

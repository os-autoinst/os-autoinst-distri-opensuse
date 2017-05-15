# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
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

sub run() {
    my $self   = shift;
    my $module = "timezone";

    $self->launch_yast2_module_x11($module);
    assert_screen [qw(yast2-datetime-ui yast2-datetime_ntp-conf)];
    if (match_has_tag 'yast2-datetime_ntp-conf') {
        send_key 'alt-d';
        send_key 'alt-o';
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
# vim: set sw=4 et:

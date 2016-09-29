# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: First commit for tracker cases. Still need to modify main.pm to make it work.
# G-Maintainer: nick wang <nwang@suse.com>

use base "x11regressiontest";
use strict;
use testapi;

# Case 1436344-start preference of tracker

sub run() {
    my $self = shift;
    x11_start_program("tracker-preferences");
    sleep 2;
    wait_idle;
    assert_screen 'tracker_pref_launched';
    send_key "alt-f4";
    sleep 2;

    # assert_screen 'test-tracker_pref_starts-2', 3;
}

sub checklist() {

    # return hashref:
    return {
        qw(
          )};
}

1;
# vim: set sw=4 et:

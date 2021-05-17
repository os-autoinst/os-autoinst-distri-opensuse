# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: tracker
# Summary: Tracker: tracker info for file
# - Launch a xterm
# - Run "tracker info newpl.pl" or "tracker-info newpl.pl" if older than
# SLE12SP2
# - Check if output matches
# - Close xterm
# Maintainer: nick wang <nwang@suse.com>
# Tags: tc#1436341

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

sub run {
    x11_start_program('xterm');
    if (is_sle('<12-SP2')) {
        script_run "tracker-info newpl.pl";
    }
    else {
        my $trackercmd = (is_sle('<16') or is_leap('<16.0')) ? 'tracker' : 'tracker3';
        script_run "$trackercmd info newpl.pl";
    }
    assert_screen 'tracker-info-newpl';
    send_key "alt-f4";
}

1;

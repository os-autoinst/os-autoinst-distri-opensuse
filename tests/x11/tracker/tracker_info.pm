# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
use testapi;
use utils;
use version_utils qw(is_sle is_leap);
use x11utils 'default_gui_terminal';

sub run {
    x11_start_program(default_gui_terminal);
    if (is_sle('<12-SP2')) {
        script_run "tracker-info newpl.pl";
    }
    else {
        my $trackercmd;
        if (is_sle('<=15-sp3') || is_leap('<=15.3')) {
            $trackercmd = 'tracker';
        }
        elsif (is_sle('>15-sp3') || is_leap('>15.3')) {
            $trackercmd = 'tracker3';
        }
        else {
            $trackercmd = 'localsearch';
        }
        script_run "$trackercmd info newpl.pl";
    }
    assert_screen 'tracker-info-newpl';
    send_key "alt-f4";
}

1;

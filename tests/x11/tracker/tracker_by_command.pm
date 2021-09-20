# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: tracker
# Summary: Tracker: search from command line
# - Launch xterm
# - Run "tracker-search newfile" if version is older than SLE12SP2
# - Otherwise, run "tracker search emptyfile"
# - Wait 20 seconds, run "tracker search newfile"
# - Check output of command
# - Close xterm
# Maintainer: nick wang <nwang@suse.com>
# Tags: tc#1436343

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

sub run {
    x11_start_program('xterm');
    if (is_sle('<12-SP2')) {
        script_run "tracker-search newfile";
    }
    else {
        my $trackercmd = (is_sle('<=15-sp3') or is_leap('<=15.3')) ? 'tracker' : 'tracker3';
        script_run "$trackercmd search emptyfile";
        assert_screen([qw(tracker-cmdsearch-emptyfile tracker-cmdsearch-noemptyfile)]);
        if (match_has_tag 'tracker-cmdsearch-noemptyfile') {
            record_soft_failure 'bsc#1190296 tracker3 can not index empty files for the first time';
            enter_cmd "clear";
            wait_still_screen 10;
            assert_script_run "$trackercmd search emptyfile";
            assert_screen 'tracker-cmdsearch-emptyfile';
        }
        script_run "$trackercmd search newfile";
    }
    assert_screen 'tracker-cmdsearch-newfile';
    send_key 'alt-f4';
}

1;

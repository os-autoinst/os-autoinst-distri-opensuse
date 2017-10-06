# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Tracker: search from command line
# Maintainer: nick wang <nwang@suse.com>
# Tags: tc#1436343

use base "x11regressiontest";
use strict;
use testapi;
use utils;


sub run {
    x11_start_program('xterm', target_match => 'xterm');
    if (sle_version_at_least('12-SP2')) {
        script_run "tracker search newfile";
    }
    else {
        script_run "tracker-search newfile";
    }
    assert_screen 'tracker-cmdsearch-newfile';
    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:

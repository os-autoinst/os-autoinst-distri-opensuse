# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Tracker: search from command line
# Maintainer: nick wang <nwang@suse.com>
# Tags: tc#1436343

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    x11_start_program('xterm');
    if (is_sle('<12-SP2')) {
        script_run "tracker-search newfile";
    }
    else {
        script_run 'tracker search emtpyfile';
        record_soft_failure 'bsc#1074582 tracker can not index empty file automatically' if check_screen 'tracker-cmdsearch-noemptyfile', 30;
        # Wait 20s for tracker to index the test file
        wait_still_screen 20;
        script_run "tracker search newfile";
    }
    assert_screen 'tracker-cmdsearch-newfile';
    send_key 'alt-f4';
}

1;

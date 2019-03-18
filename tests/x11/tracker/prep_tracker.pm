# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: First commit for tracker cases. Still need to modify main.pm to make it work.
# Maintainer: Chingkai <qkzhu@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;

# Preparation for testing tracker.

# Used for 106_tracker_info
my @filenames = qw(newfile newpl.pl);

sub run {
    x11_start_program('xterm', target_match => 'xterm');
    # Create test files with contents
    foreach (@filenames) {
        assert_script_run("echo 'Hello tracker!' > $_");
    }
    # Create an empty test file
    assert_script_run 'touch emptyfile';
    send_key 'alt-f4';
}

sub test_flags {
    return {milestone => 1};
}

1;

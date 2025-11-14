# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: First commit for tracker cases. Still need to modify main.pm to make it work.
# Maintainer: Zhaocong Jia <zcjia@suse.com> Grace Wang <grace.wang@suse.com>

use base "x11test";
use testapi;
use x11utils 'default_gui_terminal';

# Preparation for testing tracker.

# Used for 106_tracker_info
my @filenames = qw(newfile newpl.pl);

sub run {
    x11_start_program(default_gui_terminal);
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

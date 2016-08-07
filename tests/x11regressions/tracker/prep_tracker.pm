# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11regressiontest";
use strict;
use testapi;

# Preparation for testing tracker.

# Used for 106_tracker_info
my @filenames = qw/newfile newpl.pl/;

sub run() {
    my $self = shift;

    # Create a file.
    foreach (@filenames) {
        x11_start_program("touch $_");
        sleep 2;
    }
    wait_idle;
}

sub test_flags() {
    return {important => 1, milestone => 1};
}

1;
# vim: set sw=4 et:

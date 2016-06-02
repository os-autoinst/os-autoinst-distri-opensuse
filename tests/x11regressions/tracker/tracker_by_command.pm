# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

# Case 1436343 - Tracker: search from command line

sub run() {
    my $self = shift;
    x11_start_program("xterm");
    if (main::version_at_least('12-SP2')) {
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

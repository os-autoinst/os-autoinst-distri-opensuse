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
use utils;

# for https://bugzilla.novell.com/show_bug.cgi?id=657626

sub run() {
    my $self = shift;
    x11_start_program("xterm");
    script_run("cd /tmp");
    script_run("wget -q openqa.opensuse.org/opensuse/qatests/qa_mozmill_run.sh");
    script_run("sh -x qa_mozmill_run.sh");
    sleep 30;
    local $bmwqemu::timesidleneeded = 4;

    for (1 .. 12) {    # one test takes ~7 mins
        send_key "shift";    # avoid blank/screensaver
        last if wait_serial "mozmill testrun finished", 120;
    }
    assert_screen_with_soft_timeout('test-mozmill_run-1', soft_timeout => 3);
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:

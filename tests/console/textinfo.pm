# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Rework the tests layout.
# G-Maintainer: Alberto Planas <aplanas@suse.com>

use base "consoletest";
use strict;
use testapi;

# have various useful general info included in videos
sub run {
    select_console 'root-console';
    # If we're doing this test as the user root, we will not find the textinfo script
    # in /home/root but rather in /root
    if ($username eq 'root') {
        assert_script_run("/root/data/textinfo 2>&1 | tee /tmp/info.txt");
    }
    else {
        assert_script_run("/home/$username/data/textinfo 2>&1 | tee /tmp/info.txt");
    }
    upload_logs("/tmp/info.txt");
    upload_logs("/tmp/logs.tar.bz2");
}

1;
# vim: set sw=4 et:

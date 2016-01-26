# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

# have various useful general info included in videos
sub run() {
    select_console 'root-console';
    assert_script_run("/home/$username/data/textinfo 2>&1 | tee /tmp/info.txt");
    upload_logs("/tmp/info.txt");
    upload_logs("/tmp/logs.tar.bz2");
    assert_screen "texinfo-logs-uploaded";
}

1;
# vim: set sw=4 et:

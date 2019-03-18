# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Get useful text-based information from the system and upload it as a log.
#          For more information regarding the collected data, check data/textinfo
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;

# have various useful general info included in videos
sub run {
    select_console 'root-console';
    # If we're doing this test as the user root, we will not find the textinfo script
    # in /home/root, so we'll set $home with the appropiate home directory
    my $home = $username eq 'root' ? '/root' : "/home/$username";
    assert_script_run("$home/data/textinfo 2>&1 | tee /tmp/info.txt");
    upload_logs("/tmp/info.txt");
    upload_logs("/tmp/logs.tar.bz2");
}

1;

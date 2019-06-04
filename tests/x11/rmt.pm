# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add rmt configuration test and disconnect RMT test
#    test basic configuration via rmt-wizard, test disconnect RMT
#    via import RMT data and repos from an existing RMT server,
#    then verify enabled repos are shown on new RMT server.
# Maintainer: Lemon Li <leli@suse.com>

use strict;
use warnings;
use testapi;
use base 'x11test';
use repo_tools;
use utils;
use x11utils 'turn_off_gnome_screensaver';

sub run {
    x11_start_program('xterm -geometry 150x35+5+5', target_match => 'xterm');
    # Avoid blank screen since smt sync needs time
    turn_off_gnome_screensaver;
    become_root;
    rmt_wizard();
    # mirror and sync a base repo from SCC
    rmt_mirror_repo();
    # import data and repos from an existing RMT server
    rmt_import_data("rmt_external.tar.gz");
    type_string "killall xterm\n";
}

sub test_flags {
    return {fatal => 1};
}

1;

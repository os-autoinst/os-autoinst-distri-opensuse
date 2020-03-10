# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Install the rstudio base package and Firefox
# Maintainer: Dan Čermák <dcermak@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run() {
    # increase timeout to 15 mins, shouldn't take as long, but it occasionally does
    ensure_installed('rstudio MozillaFirefox', timeout => 900);

    # setup git for later usage
    x11_start_program('xterm');
    assert_script_run('git config --global user.name "Geeko"');
    assert_script_run('git config --global user.email "geeko-noreply@opensuse.org"');
    wait_still_screen(1);
    send_key("alt-f4");
}

sub test_flags {
    return {milestone => 1};
}

1;

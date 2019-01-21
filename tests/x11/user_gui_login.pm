# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Login as user test https://progress.opensuse.org/issues/13306
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "x11test";
use strict;
use testapi;
use utils;

sub run {
    handle_relogin;
    assert_screen 'generic-desktop', 90;    # x11test is checking generic-desktop in post_run_hook but after login it can take longer than 30 sec
}

1;

# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Special handling to get to the desktop the first time after
#          the installation has been completed (either find the desktop after
#          auto-login or handle the login screen to reach the desktop)
# - Wait for login screen
# - Handle displaymanager
# - Handle login screen
# - Check if generic-desktop was reached
# Maintainer: Max Lin <mlin@suse.com>

use strict;
use warnings;
use base 'bootbasetest';

sub run {
    shift->wait_boot_past_bootloader;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

# 'generic-desktop' already checked in wait_boot_past_bootloader
sub post_run_hook { }

1;

## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot the system installed by Agama.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use grub_utils qw(grub_test);

sub run {
    grub_test();
    shift->wait_boot_past_bootloader();
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_run_hook { }

1;

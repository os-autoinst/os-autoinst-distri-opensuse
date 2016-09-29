# G-Summary: virtualization initial xen support (#1575)
# G-Maintainer: xiao li ai <xlai@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use virt_utils;

sub run() {
    set_serialdev;
    setup_console_in_grub;
}

sub test_flags {
    return {important => 1};
}

1;


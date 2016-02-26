# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "basetest";
use strict;
use testapi;
use utils;

sub run() {
    send_key_until_needlematch("ovmf-mainscreen", 'delete', 5, 1);
    send_key 'down';
    send_key 'down';    # boot manager
    send_key 'ret';
    if (check_var('BOOTFROM', 'd')) {
        send_key_until_needlematch("ovmf-boot-DVD", 'down', 5, 1);
    }
    elsif (check_var('BOOTFROM', 'c')) {
        send_key_until_needlematch("ovmf-boot-HDD", 'down', 5, 1);
    }
    else {
        die "BOOTFROM value not supported";
    }
    send_key 'ret';
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:

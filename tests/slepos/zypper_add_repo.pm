# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic SLEPOS test
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;
use mm_network;
use lockapi;

sub run {
    my $smt = get_var('SMT_SERVER');

    my $slepos_repo         = get_var('SLEPOS_REPO');
    my $slepos_updates_repo = get_var('SLEPOS_UPDATES_REPO');

    if (get_var('VERSION') =~ /^11/) {
        $slepos_repo         //= 'dvd:///?devices=/dev/sr1';
        $slepos_updates_repo //= 'http://' . $smt . '/repo/$RCE/SLE11-POS-SP3-Updates/sle-11-x86_64/';
        zypper_call "ar '$slepos_repo' SLE-11-POS";
        zypper_call "ar '$slepos_updates_repo' SLE-11-POS-UPDATES";
    }
    elsif (get_var('VERSION') =~ /^12/) {
        # FIXME: no standard repos yet
        zypper_call "ar '$slepos_repo' SLE-12-POS";
        zypper_call "ar '$slepos_updates_repo' SLE-12-POS-UPDATES";
    }

    save_screenshot;
}

sub test_flags {
    return {fatal => 1};
}

1;

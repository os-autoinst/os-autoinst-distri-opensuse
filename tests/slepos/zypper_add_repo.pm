# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "basetest";
use testapi;
use utils;
use mm_network;
use lockapi;

sub run() {
    my $self = shift;

    my $smt = get_var('SMT_SERVER');

    assert_script_run "zypper ar 'dvd:///?devices=/dev/sr1' SLE-11-POS";
    assert_script_run "zypper ar 'http://$smt/repo/\$RCE/SLE11-POS-SP3-Updates/sle-11-x86_64/' SLE-11-POS-UPDATES";


    save_screenshot;
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:

# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable firewall after updating openSUSE 13.1 image
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>
# Tags: boo#977659

use base "x11test";
use strict;
use testapi;

sub run() {
    record_soft_failure('boo#1036590') if get_var('HDDVERSION', '') =~ /openSUSE-(12.1|12.2)/;
    x11_start_program('xterm');
    assert_script_sudo('SuSEfirewall2 on');
    send_key "alt-f4";
}

sub test_flags() {
    return {milestone => 1};
}

1;
# vim: set sw=4 et:

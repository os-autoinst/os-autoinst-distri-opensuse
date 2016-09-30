# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: add evince regression testsuite
#    add x11regressions test data
#
#    add gedit regression testsuite
#
#    remove unnecessary sleeps
# G-Maintainer: mitiao <mitiao@gmail.com>

use base "x11regressiontest";
use strict;
use testapi;

# Case 1436023 - Evince: Open PDF
sub run() {
    my $self = shift;
    x11_start_program("evince " . autoinst_url . "/data/x11regressions/test.pdf");

    send_key "alt-f10";    # maximize window
    assert_screen 'evince-open-pdf', 5;
    send_key "ctrl-w";     # close evince
}

1;
# vim: set sw=4 et:

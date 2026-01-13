# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: evince
# Summary: Evince: Open PDF
# - Launch evince and open test.pdf from datadir
# - Send ALT-F10 (maximize) and check
# - Close evince
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>
# Tags: tc#1436023

use base "x11test";
use testapi;


sub run {
    x11_start_program("evince " . autoinst_url . "/data/x11/test.pdf", valid => 0);

    send_key "alt-f10";    # maximize window
    assert_screen 'evince-open-pdf', 5;
    send_key "ctrl-w";    # close evince
}

# add milestone flag to open in maximized window mode by default
sub test_flags {
    return {milestone => 1};
}

1;

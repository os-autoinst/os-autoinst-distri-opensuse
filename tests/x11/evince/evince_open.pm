# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Evince: Open PDF
# Maintainer: mitiao <mitiao@gmail.com>
# Tags: tc#1436023

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    x11_start_program("evince " . autoinst_url . "/data/x11/test.pdf", valid => 0);

    send_key "alt-f10";    # maximize window
    assert_screen 'evince-open-pdf', 5;
    send_key "ctrl-w";     # close evince
}

1;

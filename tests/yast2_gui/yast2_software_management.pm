# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2
# Summary: Test YaST2 module for software management
# Maintainer: Max Lin <mlin@suse.com>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'x11';
    y2_module_guitest::launch_yast2_module_x11('sw_single', match_timeout => 100);
    # Accept => Exit, or get to the installation report
    send_key 'alt-a';
    # Installation may take some time
    assert_screen [qw(sw_single_ui_installation_report generic-desktop)], timeout => 350;
    if (match_has_tag('sw_single_ui_installation_report')) {
        # Press finish
        send_key 'alt-f';
    }
}

1;

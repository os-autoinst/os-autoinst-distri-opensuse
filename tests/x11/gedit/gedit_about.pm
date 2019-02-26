# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Gedit: help about
# Maintainer: mitiao <mitiao@gmail.com>
# Tags: tc#1436120

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    x11_start_program('gedit', target_match => 'gedit-options-icon');

    # check about window
    assert_and_click 'gedit-options-icon';
    assert_and_click 'gedit-options-about';
    assert_screen 'gedit-help-about';

    # check credits
    assert_and_click 'gedit-about-credits';
    assert_screen 'gedit-about-authors';

    send_key "esc";    # close about
    assert_screen 'gedit-launched';
    send_key "ctrl-q";
}

1;

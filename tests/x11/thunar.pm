# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: thunar
# Summary: Open thunar and navigate the root directory
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    x11_start_program('thunar', target_match => 'thunar-homedir');
    send_key "shift-tab";
    send_key "home";
    send_key "down";
    assert_screen 'test-thunar-1';
    send_key "alt-f4";
}

1;

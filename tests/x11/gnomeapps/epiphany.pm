# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: epiphany
# Summary: Epiphany - Web browser - Minimal Test
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    assert_gui_app('epiphany', remain => 1);
    if (match_has_tag 'epiphany-set-default-browser') {
        send_key('alt-n');
        sleep 1;
        assert_screen('test-epiphany-started');
    }
    send_key('alt-f4');
}

1;

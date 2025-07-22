# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: midori
# Summary: simple midori
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use testapi;
use utils 'assert_gui_app';

sub run {
    assert_gui_app('midori', install => 1);
}

1;

# SUSE's openQA tests
#
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: totem
# Summary: Totem launch
# - Install totem if necessary
# - Launch totem
# - Check if totem was launched
# - Close totem
# Maintainer: Grace Wang <gwang@suse.com>

use base "x11test";
use testapi;
use utils;

sub run {
    assert_gui_app('totem');
}

1;

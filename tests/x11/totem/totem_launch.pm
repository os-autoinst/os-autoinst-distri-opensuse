# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: totem
# Summary: Totem launch
# - Install totem if necessary
# - Launch totem
# - Check if totem was launched
# - Close totem
# Maintainer: Grace Wang <gwang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    assert_gui_app('totem');
}

1;

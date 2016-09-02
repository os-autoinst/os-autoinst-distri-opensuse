# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "y2logsstep";
use strict;
use testapi;
use utils qw/addon_license/;

sub run() {
    assert_screen 'additional-products';
    send_key 'alt-p';
    for my $addon (split(/,/, get_var('DUD_ADDONS'))) {
        addon_license($addon);
    }
}

1;
# vim: sw=4 et

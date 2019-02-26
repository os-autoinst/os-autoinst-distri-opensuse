# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Addon added via dud
#    https://trello.com/c/h7DzsthA/647-3-sle-12-sp2-p1-992608-add-ons-added-via-add-on-products-xml-are-lost-after-self-update
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "y2logsstep";
use strict;
use warnings;
use testapi;
use utils 'addon_license';
use version_utils 'is_sle';

sub run {
    # On SLE 15 screen is shown before welcome, hence requires time to be loaded
    assert_screen 'additional-products', (is_sle('15+') ? 500 : 60);
    send_key 'alt-p';
    # With SLE 15 we have different mechanism for the licenses
    return if is_sle('15+');
    for my $addon (split(/,/, get_var('DUD_ADDONS'))) {
        addon_license($addon);
    }
}

1;

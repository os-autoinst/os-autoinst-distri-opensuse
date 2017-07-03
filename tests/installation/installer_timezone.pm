# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify timezone settings page and proceed to next page
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use strict;
use base "y2logsstep";
use testapi;
use main_common "noupdatestep_is_applicable";

sub run() {
    assert_screen "inst-timezone", 125 || die 'no timezone';
    # Different hotkey on kde live distri
    if (noupdatestep_is_applicable() && get_var("LIVECD")) {
        send_key "alt-x";
    }
    else {
        send_key $cmd{next};
    }
}

1;
# vim: set sw=4 et:

# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test module to activate multipath during initial installation
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    # Sometimes multipath detection takes longer
    assert_screen "enable-multipath", 60;
    # This module is supposed to be invoked only if MULTIPATH is true
    # or MULTIPATH_DIALOG_YES is set
    if (get_var("MULTIPATH") or get_var("MULTIPATH_DIALOG_YES")) {
        send_key "alt-y";
    }
    else {
        # MULTIPATH_DIALOG_YES set to false
        send_key "alt-n";
    }
}

1;

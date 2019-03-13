# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test module to activate multipath
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base "y2logsstep";
use strict;
use warnings;
use testapi;

sub run {
    # Sometimes multipath detection takes longer
    assert_screen "enable-multipath", 60;
    send_key "alt-y";
}

1;

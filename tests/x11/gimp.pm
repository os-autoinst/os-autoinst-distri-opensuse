# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test startup of gimp
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    ensure_installed("gimp");
    x11_start_program('gimp');
    # sometimes send_key "alt-f4" doesn't work reliable, so repeat it and exit
    send_key_until_needlematch 'generic-desktop', "alt-f4", 5, 5;
}

1;

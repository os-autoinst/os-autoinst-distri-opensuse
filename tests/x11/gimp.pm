# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gimp
# Summary: Test startup of gimp
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    ensure_installed("gimp");
    x11_start_program('gimp', match_timeout => 60);
    # sometimes send_key "alt-f4" doesn't work reliable, so repeat it and exit
    send_key_until_needlematch 'generic-desktop', "alt-f4", 6, 5;
}

1;

# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemsettings
# Summary: Show started systemsettings
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use testapi;

sub run {
    x11_start_program('systemsettings');
    send_key "alt-f4";
}

1;

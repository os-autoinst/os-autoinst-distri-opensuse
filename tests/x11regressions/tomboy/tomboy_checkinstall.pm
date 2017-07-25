# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install tomboy
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11regressiontest";
use strict;
use testapi;


sub run {
    mouse_hide();
    sleep 60;
    ensure_installed("tomboy");
    send_key "ret";
    sleep 90;
    send_key "esc";
    sleep 5;
}

1;
# vim: set sw=4 et:

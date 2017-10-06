# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: glxgears can start
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use testapi;

sub run {
    ensure_installed 'Mesa-demo-x';
    # 'no_wait' for still screen because glxgears will be always moving
    x11_start_program('glxgears', no_wait => 1);
    assert_screen 'test-glxgears-1';
    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:

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
use warnings;
use testapi;

sub run {
    ensure_installed 'Mesa-demo-x';
    # as glxgears is constantly moving:
    # 'no_wait' to not wait for a still screen after the program has started
    # 'match_no_wait' to check the screen as often as possible
    x11_start_program('glxgears', match_no_wait => 1, no_wait => 1);
    send_key 'alt-f4';
}

1;

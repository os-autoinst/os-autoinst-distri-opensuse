# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: change to nicer directory structure
# G-Maintainer: Bernhard M. Wiedemann <bernhard+osautoinst lsmod de>

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    assert_screen "inst-timezone", 125 || die 'no timezone';
    send_key $cmd{next};
}

1;
# vim: set sw=4 et:

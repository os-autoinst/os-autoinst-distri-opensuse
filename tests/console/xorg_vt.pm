# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Rework the tests layout.
# Maintainer: Alberto Planas <aplanas@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    # permissions don't matter

    script_run('ps -ef | grep bin/X');
    assert_screen("xorg-tty7");    # suppose used terminal is tty7
}

1;

# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: gnote startup
# Maintainer: Xudong Zhang <xdzhang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_tumbleweed';

sub run {
    if (is_tumbleweed) {
        select_console('root-console');
        pkcon_quit;
        zypper_call('in gnote');
        select_console('x11');
    }
    x11_start_program('gnote');
    send_key "ctrl-w";
}

# add milestone flag to save gnote installation in lastgood vm snapshot
sub test_flags {
    return {milestone => 1};
}

1;

# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
#
# Summary: 
# Maintainer: Christopher Hofmann <cwh@suse.de> 

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    send_key $cmd{expertpartitioner};
    assert_screen 'expert-partitioner';

    assert_and_click 'hard-disks';
    assert_and_click 'home';

    send_key 'alt-d'; # Delete
    send_key 'alt-y'; # Confirm with 'yes'
    assert_and_click 'hard-disks';
    save_screenshot;

    send_key $cmd{accept};
    die "/home still there" if check_screen('home');
}

1;
# vim: set sw=4 et:

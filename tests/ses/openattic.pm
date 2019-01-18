# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: openattic test
# Maintainer: Jozef Pupava <jpupava@suse.cz>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use x11test;
use mm_network;
use lockapi;
use utils 'zypper_call';

sub run {
    my ($self) = @_;
    if (check_var('HOSTNAME', 'master')) {
        # install firefox and icewm to test openattic
        zypper_call 'in firefox icewm xinit xorg-x11-server';
        type_string "startx\n";    # start icewm
        assert_screen 'generic-desktop';
        mouse_set 100, 100;
        mouse_click 'right';
        send_key_until_needlematch 'xterm', 'ret';
        type_string "firefox http://master\n";    # open openattic web running on master node
        $self->x11test::firefox_check_default;    # close default browser pop-up
        assert_screen 'openattic-login';
        send_key 'tab';                           # username login field
        type_string 'openattic';
        send_key 'tab';                           # password field
        type_string "openattic\n";
        assert_and_click 'firefox-passwd-confirm_remember';
        send_key 'esc';                           # get rid of unsecure connection pop-up
        assert_screen 'openattic-dashboard';
        send_key_until_needlematch 'openattic-health-status-ok', 'f5', 10, 30;
        barrier_wait {name => 'all_tests_done', check_dead_job => 1};
    }
    else {
        barrier_wait {name => 'all_tests_done'};
    }
}

1;


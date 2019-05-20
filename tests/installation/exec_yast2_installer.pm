# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Start YaST2 installer
# Maintainer: mloviska@suse.com

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use utils 'type_string_slow';

sub run {
    my $ssh_vnc_wait_time = 300;
    my $ssh_vnc_tag       = eval { check_var('VIDEOMODE', 'text') ? 'sshd' : 'vnc' } . '-server-started';

    assert_screen([$ssh_vnc_tag, 'media_error'], $ssh_vnc_wait_time);
    if (match_has_tag('media_error')) {
        set_var('_SKIP_POST_FAIL_HOOKS', 1);
        die "Media error! Check the installation media!\n";
    }

    select_console 'installation';

    # We have textmode installation via ssh and the default vnc installation so far
    if (check_var('VIDEOMODE', 'text') || check_var('VIDEOMODE', 'ssh-x')) {
        type_string_slow('DISPLAY= ') if check_var('VIDEOMODE', 'text');
        type_string_slow("yast.ssh\n");
        wait_still_screen(stilltime => 0.5, timeout => 5, similarity_level => 45);
        save_screenshot;
    }
    assert_screen('yast-still-running', 120);
}

sub test_flags { return fatal => 1; }

1;

# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: nautilus
# Summary: Test nautilus open ftp
# Maintainer: QE Core <qe-core@suse.de>
# Tags: tc#1436143


use base 'x11test';
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_tumbleweed);

sub run {
    x11_start_program('nautilus');
    wait_screen_change { send_key 'ctrl-l' };
    enter_cmd "ftp://ftp.suse.com";
    assert_screen 'nautilus-ftp-login';
    send_key 'ret';
    assert_screen 'nautilus-ftp-suse-com';
    assert_and_click('ftp-path-selected', button => 'right');
    assert_screen 'nautilus-ftp-rightkey-menu';
    # unmount ftp
    assert_and_click 'nautilus-unmount';
    assert_screen 'nautilus-launched';
    send_key 'ctrl-w';
}

1;

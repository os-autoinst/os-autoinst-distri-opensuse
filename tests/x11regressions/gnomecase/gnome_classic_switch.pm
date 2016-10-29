# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Gnome: switch between gnome(now default is sle-classic) and gnome-classic
# Maintainer: xiaojun <xjin@suse.com>
# Tags: tc#5255-1503849

use base "x11regressiontest";
use strict;
use testapi;
use utils;

# applications are called twiced
sub application_test {
    x11_start_program "gnome-terminal";
    assert_screen "gnome-terminal-launched";
    send_key "alt-f4";
    send_key "ret";
    wait_still_screen;

    x11_start_program "firefox";
    assert_screen "firefox-gnome", 150;
    send_key "alt-f4";
    wait_still_screen;
    send_key "ret";
    wait_still_screen;

}

sub run () {
    my ($self) = @_;
    $self->prepare_sle_classic;
    $self->application_test;
}

1;
# vim: set sw=4 et:

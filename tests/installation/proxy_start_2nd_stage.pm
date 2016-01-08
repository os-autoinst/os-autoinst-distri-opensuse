# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use strict;
use testapi;

sub reconnectsshinstall($) {
    my ($nodenum) = @_;
    my $nodeip = 5 + $nodenum;
    type_string "ssh 10.0.2.1$nodeip -l root\n";
    sleep 10;
    type_string "openqaha\n";
    sleep 10;
    type_string "/usr/lib/YaST2/startup/YaST2.ssh\n";
    assert_screen 'second-stage', 40;
}

sub waitfor2ndstage($) {
    my ($nodenum) = @_;
    type_string "vncviewer localhost:9$nodenum -shared -fullscreen\n";
    assert_screen "inst-ssh-ready", 500;
    send_key 'f8',                  1;
    send_key 'down',                1;
    send_key 'ret',                 1;
    sleep 5;
    send_key 'ctrl-l', 1;
}

sub run() {
    waitfor2ndstage "1";
    reconnectsshinstall "1";
}

1;
# vim: set sw=4 et:

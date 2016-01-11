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

sub startsshinstall($) {
    my ($nodenum) = @_;
    my $nodeip = 5 + $nodenum;
    type_string "ssh 10.0.2.1$nodeip -l root\n";
    sleep 10;
    type_string "yes\n";
    sleep 10;
    type_string "openqaha\n";
    sleep 10;
    type_string "yast\n";
    assert_screen 'inst-welcome-start', 15;
}

sub run() {
    assert_screen 'proxy-terminator-clean';
    startsshinstall "1";    # only need one VM now
}

1;

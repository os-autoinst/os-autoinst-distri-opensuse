# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    send_key "ctrl-l";
    script_run('ps -ef | grep bin/X');
    assert_screen("xorg-tty7");    # suppose used terminal is tty7
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:

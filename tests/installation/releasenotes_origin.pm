# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check origin of displayed releasenotes during installation
# Maintainer: mgriessmeier <mgriessmeier@suse.com>, Nick Singer <nsinger@suse.de>
# Tags: fate#323273, poo#26786

use strict;
use base "y2logsstep";
use testapi;

sub run {
    assert_screen('release-notes-button');
    send_key('ctrl-shift-alt-x');
    assert_screen('yast-xterm');
    my $src = check_var('SCC_REGISTER', 'installation') ? "RPM" : "URL";
    type_string "grep -o \"Got release notes.*$src\" /var/log/YaST2/y2log\n";
    assert_screen "got-releasenotes-$src";
    type_string "exit\n";
    assert_screen 'system-role-default-system', 180;
}

1;

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
use strict;
use testapi;
use utils;

sub run() {
    select_console 'user-console';
    script_run('test -L /etc/mtab && echo OK || echo fail');
    assert_screen_with_soft_timeout("test-mtab-1", soft_timeout => 3);
    script_run('cat /etc/mtab');
    save_screenshot;
}

1;
# vim: set sw=4 et:

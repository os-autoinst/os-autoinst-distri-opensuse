# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Rework the tests layout.
# - Run test as user
# - Run "test -L /etc/mtab"
# - Run "cat /etc/mtab"
# - Save screenshot
# Maintainer: Alberto Planas <aplanas@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'user-console';
    assert_script_run 'test -L /etc/mtab';
    script_run('cat /etc/mtab');
    save_screenshot;
}

1;

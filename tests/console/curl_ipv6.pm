# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test curl fallback from IPv6 to IPv4
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: bsc#598574

use base "consoletest";
use testapi;
use strict;
use warnings;

sub run {
    select_console 'user-console';
    assert_script_run('curl www3.zq1.de/test.txt');
    assert_script_run('rpm -q curl libcurl4');
}

1;

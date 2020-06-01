# SUSE's Apache+SSL tests
#
# Copyright © 2016-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Enable SSL module on Apache2 server
#          calls setup_apache2 with mode = SSL (lib/apachetest.pm)
#
# Maintainer: Ben Chou <bchou@suse.com>
# Tags: poo#65375, poo#67309

use base "consoletest";
use testapi;
use strict;
use warnings;
use apachetest;
use utils 'clear_console';

sub run {
    select_console 'root-console';
    clear_console;
    setup_apache2(mode => 'SSL');
}

sub test_flags {
    return {fatal => 0};
}

1;

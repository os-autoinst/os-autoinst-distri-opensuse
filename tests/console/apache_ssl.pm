# SUSE's Apache+SSL tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable SSL module on Apache2 server
# Maintainer: Qingming Su <qingming.su@suse.com>

use base "consoletest";
use testapi;
use strict;
use warnings;
use apachetest;

sub run {
    select_console 'root-console';
    setup_apache2(mode => 'SSL');
}

1;

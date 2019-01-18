# SUSE's Apache+NSSFips tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable NSS module for Apache2 server with NSSFips on
# Maintainer: Qingming Su <qingming.su@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use apachetest;

sub run {
    select_console 'root-console';
    setup_apache2(mode => 'NSSFIPS');
}

1;

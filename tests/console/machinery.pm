# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add simple machinery test thanks to greygoo (#1592)
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';
    assert_script_run 'which OneClickInstallCLI || zypper -n in yast2-metapackage-handler', 200;
    my $ret_check = '[ "$?" = "141" ] || [ "$?" = "0" ]';
    assert_script_run 'yes | OneClickInstallCLI http://machinery-project.org/machinery.ymp ; ' . $ret_check, 200;
    validate_script_output 'machinery --help', sub { m/machinery - A systems management toolkit for Linux/ }, 100;
}

1;

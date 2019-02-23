# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test OneClickInstallCLI
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    assert_script_run 'which OneClickInstallCLI || zypper -n in yast2-metapackage-handler',                                                   200;
    assert_script_run 'yes | OneClickInstallCLI https://software.opensuse.org/ymp/openSUSE:Factory/standard/xosview.ymp || [ "$?" = "141" ]', 200;
    assert_script_run 'which xosview';
}

1;

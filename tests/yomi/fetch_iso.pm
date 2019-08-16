# Yomi's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Fetch Yomi image from OBS
# Maintainer: Alberto Planas <aplanas@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';

    my $base_url = 'https://download.opensuse.org/repositories/systemsmanagement:/yomi/images/iso/';
    my $iso      = 'openSUSE-Tumbleweed-Yomi.x86_64-*.iso';
    assert_script_run "wget -r -l1 -np -nd '$base_url' -A '$iso'", timeout => 360;
}

sub test_flags {
    return {fatal => 1};
}

1;

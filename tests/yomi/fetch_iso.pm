# Yomi's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
    my $iso = 'openSUSE-Tumbleweed-Yomi.x86_64-*.iso';
    assert_script_run "wget -r -l1 -np -and '$base_url' -A '$iso'", timeout => 360;
}

sub test_flags {
    return {fatal => 1};
}

1;
